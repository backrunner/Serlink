This is a local copy of `flutter_pty` 0.4.2 with Serlink-specific Windows
ConPTY fixes. Only `src/flutter_pty_win.c` differs from upstream; the
`example/` directory was not copied.

Current patches:

- Convert the UTF-8 executable, arguments, environment and working directory
  to UTF-16 with `MultiByteToWideChar`. Upstream widened each byte, which broke
  non-ASCII user profile paths and environment values.
- Build the command line from argv[0] plus the remaining arguments with
  `CommandLineToArgvW` quoting. Upstream repeated the executable (argv[0] was
  appended after the program name) and never quoted paths containing spaces,
  so `pwsh.exe` and `C:\Program Files\...` shells failed to start.
- Sort the Unicode environment block by name as `CreateProcess` documents.
- Remove the unconditional one second `Sleep` before every spawn.
- Close the pipe ends owned by the pseudo console after creation and close the
  pseudo console when the child exits, so the reader thread and conhost end
  instead of leaking per closed tab. Resize is ignored after that point.
- Report the Windows error code in `pty_error` messages.
