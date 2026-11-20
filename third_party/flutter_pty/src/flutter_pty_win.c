// Windows ConPTY backend.
//
// Serlink patches (see ../README.serlink.md):
// - Convert UTF-8 executable, arguments, environment and working directory to
//   UTF-16 instead of widening each byte, so non-ASCII paths and values work.
// - Build the command line from argv[0] plus the remaining arguments using
//   CommandLineToArgvW quoting rules. Upstream appended the executable twice
//   and never quoted paths containing spaces.
// - Sort the environment block as CreateProcess documents.
// - Drop the unconditional one second sleep before every spawn.
// - Close the pseudo console after the child exits so the output reader and
//   conhost terminate, guarding resize against the closed handle.

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <wchar.h>
#include <Windows.h>

#include "flutter_pty.h"

#include "include/dart_api.h"
#include "include/dart_api_dl.h"
#include "include/dart_native_api.h"

static char error_buffer[256];

char *error_message = NULL;

static void set_error(const char *message, DWORD code)
{
    if (code != 0)
    {
        snprintf(error_buffer, sizeof(error_buffer), "%s (Windows error %lu)",
                 message, (unsigned long)code);
    }
    else
    {
        snprintf(error_buffer, sizeof(error_buffer), "%s", message);
    }
    error_message = error_buffer;
}

static LPWSTR utf8_to_wide(const char *value)
{
    if (value == NULL)
    {
        return NULL;
    }

    int length = MultiByteToWideChar(CP_UTF8, 0, value, -1, NULL, 0);

    if (length <= 0)
    {
        return NULL;
    }

    LPWSTR result = malloc((size_t)length * sizeof(WCHAR));

    if (result == NULL)
    {
        return NULL;
    }

    if (MultiByteToWideChar(CP_UTF8, 0, value, -1, result, length) <= 0)
    {
        free(result);
        return NULL;
    }

    return result;
}

typedef struct WideBuilder
{
    WCHAR *data;

    size_t length;

    size_t capacity;

    BOOL failed;

} WideBuilder;

static void builder_reserve(WideBuilder *builder, size_t extra)
{
    if (builder->failed)
    {
        return;
    }

    size_t required = builder->length + extra + 1;

    if (required <= builder->capacity)
    {
        return;
    }

    size_t capacity = builder->capacity == 0 ? 256 : builder->capacity;

    while (capacity < required)
    {
        capacity *= 2;
    }

    WCHAR *data = realloc(builder->data, capacity * sizeof(WCHAR));

    if (data == NULL)
    {
        builder->failed = TRUE;
        return;
    }

    builder->data = data;
    builder->capacity = capacity;
}

static void builder_append_char(WideBuilder *builder, WCHAR value)
{
    builder_reserve(builder, 1);

    if (builder->failed)
    {
        return;
    }

    builder->data[builder->length++] = value;
    builder->data[builder->length] = 0;
}

static void builder_append_repeated(WideBuilder *builder, WCHAR value, size_t count)
{
    for (size_t i = 0; i < count; i++)
    {
        builder_append_char(builder, value);
    }
}

static void builder_append(WideBuilder *builder, const WCHAR *value)
{
    while (*value != 0)
    {
        builder_append_char(builder, *value);
        value++;
    }
}

// argv[0] is parsed without backslash escapes; quote it only when needed.
static void append_program(WideBuilder *builder, const WCHAR *program)
{
    if (program[0] != 0 && wcspbrk(program, L" \t") == NULL)
    {
        builder_append(builder, program);
        return;
    }

    builder_append_char(builder, L'"');
    builder_append(builder, program);
    builder_append_char(builder, L'"');
}

// Quotes one argument so CommandLineToArgvW and the MSVC CRT reproduce it.
static void append_argument(WideBuilder *builder, const WCHAR *argument)
{
    if (argument[0] != 0 && wcspbrk(argument, L" \t\n\v\"") == NULL)
    {
        builder_append(builder, argument);
        return;
    }

    builder_append_char(builder, L'"');

    const WCHAR *cursor = argument;

    while (1)
    {
        size_t backslashes = 0;

        while (*cursor == L'\\')
        {
            cursor++;
            backslashes++;
        }

        if (*cursor == 0)
        {
            builder_append_repeated(builder, L'\\', backslashes * 2);
            break;
        }

        if (*cursor == L'"')
        {
            builder_append_repeated(builder, L'\\', backslashes * 2 + 1);
            builder_append_char(builder, L'"');
        }
        else
        {
            builder_append_repeated(builder, L'\\', backslashes);
            builder_append_char(builder, *cursor);
        }

        cursor++;
    }

    builder_append_char(builder, L'"');
}

// |arguments| is a NULL-terminated argv whose first entry is the program.
static LPWSTR build_command(char *executable, char **arguments)
{
    WideBuilder builder = {0};

    LPWSTR program = utf8_to_wide(executable);

    if (program == NULL)
    {
        return NULL;
    }

    append_program(&builder, program);
    free(program);

    if (arguments != NULL && arguments[0] != NULL)
    {
        for (int i = 1; arguments[i] != NULL; i++)
        {
            LPWSTR argument = utf8_to_wide(arguments[i]);

            if (argument == NULL)
            {
                free(builder.data);
                return NULL;
            }

            builder_append_char(&builder, L' ');
            append_argument(&builder, argument);
            free(argument);
        }
    }

    if (builder.failed)
    {
        free(builder.data);
        return NULL;
    }

    return builder.data;
}

static size_t environment_name_length(const WCHAR *entry)
{
    // Names of hidden per-drive variables start with '=' (for example "=C:").
    const WCHAR *separator = wcschr(entry[0] == L'=' ? entry + 1 : entry, L'=');

    return separator == NULL ? wcslen(entry) : (size_t)(separator - entry);
}

static int compare_environment_entries(const void *left, const void *right)
{
    const WCHAR *a = *(const WCHAR *const *)left;
    const WCHAR *b = *(const WCHAR *const *)right;

    int result = CompareStringOrdinal(a, (int)environment_name_length(a), b,
                                      (int)environment_name_length(b), TRUE);

    return result == 0 ? 0 : result - CSTR_EQUAL;
}

// Returns NULL with |*ok| set when there is no environment to pass, so the
// child inherits ours.
static LPWSTR build_environment(char **environment, BOOL *ok)
{
    *ok = TRUE;

    if (environment == NULL || environment[0] == NULL)
    {
        return NULL;
    }

    int count = 0;

    while (environment[count] != NULL)
    {
        count++;
    }

    LPWSTR *entries = calloc((size_t)count, sizeof(LPWSTR));

    if (entries == NULL)
    {
        *ok = FALSE;
        return NULL;
    }

    size_t total = 1;

    for (int i = 0; i < count; i++)
    {
        entries[i] = utf8_to_wide(environment[i]);

        if (entries[i] == NULL)
        {
            *ok = FALSE;
            break;
        }

        total += wcslen(entries[i]) + 1;
    }

    LPWSTR block = NULL;

    if (*ok)
    {
        qsort(entries, (size_t)count, sizeof(LPWSTR), compare_environment_entries);

        block = malloc(total * sizeof(WCHAR));

        if (block == NULL)
        {
            *ok = FALSE;
        }
        else
        {
            size_t offset = 0;

            for (int i = 0; i < count; i++)
            {
                size_t length = wcslen(entries[i]) + 1;
                memcpy(block + offset, entries[i], length * sizeof(WCHAR));
                offset += length;
            }

            block[offset] = 0;
        }
    }

    for (int i = 0; i < count; i++)
    {
        free(entries[i]);
    }

    free(entries);

    return block;
}

typedef struct PtyHandle
{
    HANDLE inputWriteSide;

    HPCON hPty;

    DWORD dwProcessId;

    BOOL ackRead;

    HANDLE hMutex;

    SRWLOCK lock;

    BOOL closed;

} PtyHandle;

typedef struct ReadLoopOptions
{
    HANDLE fd;

    Dart_Port port;

    HANDLE hMutex;

    BOOL ackRead;

} ReadLoopOptions;

static DWORD WINAPI read_loop(LPVOID arg)
{
    ReadLoopOptions *options = (ReadLoopOptions *)arg;

    char buffer[8192];

    while (1)
    {
        DWORD readlen = 0;

        if (options->ackRead)
        {
            WaitForSingleObject(options->hMutex, INFINITE);
        }

        BOOL ok = ReadFile(options->fd, buffer, sizeof(buffer), &readlen, NULL);

        if (!ok || readlen == 0)
        {
            break;
        }

        Dart_CObject result;
        result.type = Dart_CObject_kTypedData;
        result.value.as_typed_data.type = Dart_TypedData_kUint8;
        result.value.as_typed_data.length = readlen;
        result.value.as_typed_data.values = (uint8_t *)buffer;

        Dart_PostCObject_DL(options->port, &result);
    }

    CloseHandle(options->fd);
    free(options);

    return 0;
}

typedef struct WaitExitOptions
{
    HANDLE process;

    Dart_Port port;

    PtyHandle *pty;

} WaitExitOptions;

static DWORD WINAPI wait_exit_thread(LPVOID arg)
{
    WaitExitOptions *options = (WaitExitOptions *)arg;

    DWORD exit_code = 0;

    WaitForSingleObject(options->process, INFINITE);

    GetExitCodeProcess(options->process, &exit_code);

    CloseHandle(options->process);

    PtyHandle *pty = options->pty;

    AcquireSRWLockExclusive(&pty->lock);
    HPCON hPty = pty->hPty;
    pty->hPty = NULL;
    pty->closed = TRUE;
    ReleaseSRWLockExclusive(&pty->lock);

    // Ends conhost and any console processes still attached to it; the reader
    // then sees EOF. Done outside the lock because it can wait for the reader
    // to drain the remaining output.
    if (hPty != NULL)
    {
        ClosePseudoConsole(hPty);
    }

    Dart_PostInteger_DL(options->port, (int64_t)(int32_t)exit_code);

    free(options);

    return 0;
}

static BOOL start_thread(LPTHREAD_START_ROUTINE routine, LPVOID arg)
{
    HANDLE thread = CreateThread(NULL, 0, routine, arg, 0, NULL);

    if (thread == NULL)
    {
        return FALSE;
    }

    CloseHandle(thread);

    return TRUE;
}

FFI_PLUGIN_EXPORT PtyHandle *pty_create(PtyOptions *options)
{
    HANDLE inputReadSide = NULL;
    HANDLE inputWriteSide = NULL;
    HANDLE outputReadSide = NULL;
    HANDLE outputWriteSide = NULL;
    HPCON hPty = NULL;
    LPPROC_THREAD_ATTRIBUTE_LIST attributes = NULL;
    BOOL attributesInitialized = FALSE;
    LPWSTR command = NULL;
    LPWSTR environment_block = NULL;
    LPWSTR working_directory = NULL;
    PROCESS_INFORMATION processInfo;
    ZeroMemory(&processInfo, sizeof(processInfo));
    PtyHandle *pty = NULL;
    ReadLoopOptions *readOptions = NULL;
    WaitExitOptions *exitOptions = NULL;

    if (!CreatePipe(&inputReadSide, &inputWriteSide, NULL, 0))
    {
        set_error("Failed to create input pipe", GetLastError());
        goto fail;
    }

    if (!CreatePipe(&outputReadSide, &outputWriteSide, NULL, 0))
    {
        set_error("Failed to create output pipe", GetLastError());
        goto fail;
    }

    COORD size;
    size.X = (SHORT)options->cols;
    size.Y = (SHORT)options->rows;

    HRESULT result = CreatePseudoConsole(size, inputReadSide, outputWriteSide, 0, &hPty);

    if (FAILED(result))
    {
        hPty = NULL;
        set_error("Failed to create pseudo console", (DWORD)result);
        goto fail;
    }

    // The pseudo console duplicated its ends of the pipes.
    CloseHandle(inputReadSide);
    inputReadSide = NULL;
    CloseHandle(outputWriteSide);
    outputWriteSide = NULL;

    SIZE_T bytesRequired = 0;
    InitializeProcThreadAttributeList(NULL, 1, 0, &bytesRequired);
    attributes = (LPPROC_THREAD_ATTRIBUTE_LIST)malloc(bytesRequired);

    if (attributes == NULL ||
        !InitializeProcThreadAttributeList(attributes, 1, 0, &bytesRequired))
    {
        set_error("Failed to initialize proc thread attribute list", GetLastError());
        goto fail;
    }

    attributesInitialized = TRUE;

    if (!UpdateProcThreadAttribute(attributes,
                                   0,
                                   PROC_THREAD_ATTRIBUTE_PSEUDOCONSOLE,
                                   hPty,
                                   sizeof(hPty),
                                   NULL,
                                   NULL))
    {
        set_error("Failed to update proc thread attribute list", GetLastError());
        goto fail;
    }

    STARTUPINFOEXW startupInfo;
    ZeroMemory(&startupInfo, sizeof(startupInfo));
    startupInfo.StartupInfo.cb = sizeof(startupInfo);
    startupInfo.StartupInfo.dwFlags = STARTF_USESTDHANDLES;
    startupInfo.StartupInfo.hStdInput = NULL;
    startupInfo.StartupInfo.hStdOutput = NULL;
    startupInfo.StartupInfo.hStdError = NULL;
    startupInfo.lpAttributeList = attributes;

    command = build_command(options->executable, options->arguments);

    if (command == NULL)
    {
        set_error("Failed to build the command line", 0);
        goto fail;
    }

    BOOL environmentOk = TRUE;
    environment_block = build_environment(options->environment, &environmentOk);

    if (!environmentOk)
    {
        set_error("Failed to build the environment block", 0);
        goto fail;
    }

    if (options->working_directory != NULL)
    {
        working_directory = utf8_to_wide(options->working_directory);

        if (working_directory == NULL)
        {
            set_error("Failed to convert the working directory", 0);
            goto fail;
        }
    }

    pty = calloc(1, sizeof(PtyHandle));
    readOptions = malloc(sizeof(ReadLoopOptions));
    exitOptions = malloc(sizeof(WaitExitOptions));

    if (pty == NULL || readOptions == NULL || exitOptions == NULL)
    {
        set_error("Failed to allocate pty handle", 0);
        goto fail;
    }

    pty->hMutex = CreateSemaphore(NULL, 1, 1, NULL);

    if (pty->hMutex == NULL)
    {
        set_error("Failed to create read semaphore", GetLastError());
        goto fail;
    }

    if (!CreateProcessW(NULL,
                        command,
                        NULL,
                        NULL,
                        FALSE,
                        EXTENDED_STARTUPINFO_PRESENT | CREATE_UNICODE_ENVIRONMENT,
                        environment_block,
                        working_directory,
                        &startupInfo.StartupInfo,
                        &processInfo))
    {
        set_error("Failed to create process", GetLastError());
        goto fail;
    }

    CloseHandle(processInfo.hThread);

    free(command);
    free(environment_block);
    free(working_directory);
    DeleteProcThreadAttributeList(attributes);
    free(attributes);

    pty->inputWriteSide = inputWriteSide;
    pty->hPty = hPty;
    pty->dwProcessId = processInfo.dwProcessId;
    pty->ackRead = options->ackRead;
    pty->closed = FALSE;
    InitializeSRWLock(&pty->lock);

    readOptions->fd = outputReadSide;
    readOptions->port = options->stdout_port;
    readOptions->hMutex = pty->hMutex;
    readOptions->ackRead = options->ackRead;

    exitOptions->process = processInfo.hProcess;
    exitOptions->port = options->exit_port;
    exitOptions->pty = pty;

    if (!start_thread(read_loop, readOptions))
    {
        // Without a reader the child would block on output; stop it.
        TerminateProcess(processInfo.hProcess, 1);
        CloseHandle(outputReadSide);
        free(readOptions);
    }

    if (!start_thread(wait_exit_thread, exitOptions))
    {
        // Nothing will report the exit; leave the handles for the process
        // lifetime rather than racing a late reader.
        free(exitOptions);
    }

    return pty;

fail:
    if (processInfo.hProcess != NULL)
    {
        CloseHandle(processInfo.hProcess);
    }
    if (pty != NULL && pty->hMutex != NULL)
    {
        CloseHandle(pty->hMutex);
    }
    free(pty);
    free(readOptions);
    free(exitOptions);
    free(command);
    free(environment_block);
    free(working_directory);
    if (attributesInitialized)
    {
        DeleteProcThreadAttributeList(attributes);
    }
    free(attributes);
    if (hPty != NULL)
    {
        ClosePseudoConsole(hPty);
    }
    if (inputReadSide != NULL)
    {
        CloseHandle(inputReadSide);
    }
    if (inputWriteSide != NULL)
    {
        CloseHandle(inputWriteSide);
    }
    if (outputReadSide != NULL)
    {
        CloseHandle(outputReadSide);
    }
    if (outputWriteSide != NULL)
    {
        CloseHandle(outputWriteSide);
    }
    return NULL;
}

FFI_PLUGIN_EXPORT void pty_write(PtyHandle *handle, char *buffer, int length)
{
    DWORD offset = 0;

    while (offset < (DWORD)length)
    {
        DWORD bytesWritten = 0;

        if (!WriteFile(handle->inputWriteSide, buffer + offset,
                       (DWORD)length - offset, &bytesWritten, NULL) ||
            bytesWritten == 0)
        {
            return;
        }

        offset += bytesWritten;
    }
}

FFI_PLUGIN_EXPORT void pty_ack_read(PtyHandle *handle)
{
    if (handle->ackRead)
    {
        ReleaseSemaphore(handle->hMutex, 1, NULL);
    }
}

FFI_PLUGIN_EXPORT int pty_resize(PtyHandle *handle, int rows, int cols)
{
    COORD size;

    size.X = (SHORT)cols;
    size.Y = (SHORT)rows;

    HRESULT result = E_HANDLE;

    AcquireSRWLockExclusive(&handle->lock);

    if (!handle->closed && handle->hPty != NULL)
    {
        result = ResizePseudoConsole(handle->hPty, size);
    }

    ReleaseSRWLockExclusive(&handle->lock);

    return (int)result;
}

FFI_PLUGIN_EXPORT int pty_getpid(PtyHandle *handle)
{
    return (int)handle->dwProcessId;
}

FFI_PLUGIN_EXPORT char *pty_error()
{
    return error_message;
}
