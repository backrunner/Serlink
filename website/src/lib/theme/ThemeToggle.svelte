<script lang="ts">
  import { onMount } from 'svelte';
  import { createThemeModeController, fallbackTranslate } from 'svedocs/theme/headless';
  import type { SvedocsThemeToggleProps } from 'svedocs/theme/types';
  import Icon from '../Icon.svelte';
  export let defaultMode: SvedocsThemeToggleProps['defaultMode'] = 'system';
  export let context: SvedocsThemeToggleProps['context'] = undefined;
  const controller = createThemeModeController(defaultMode);
  const preference = controller.preference;
  $: t = context?.t ?? fallbackTranslate;
  onMount(controller.mount);
  function cycle() {
    controller.setPreference($preference === 'system' ? 'light' : $preference === 'light' ? 'dark' : 'system');
  }
</script>
<button class="sl-icon-button" type="button" on:click={cycle} aria-label={`${t('theme.label')}: ${t(`theme.${$preference}`)}`} title={`${t('theme.label')}: ${t(`theme.${$preference}`)}`} data-testid="theme-toggle"><Icon name={$preference === 'light' ? 'sun' : $preference === 'dark' ? 'moon' : 'system'} size={18} /></button>
