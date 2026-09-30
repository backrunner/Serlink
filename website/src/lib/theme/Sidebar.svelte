<script lang="ts">
  import type { SvedocsSidebarProps } from 'svedocs/theme/types';
  export let items: NonNullable<SvedocsSidebarProps['items']> = [];
  export let currentPath = '';
  export let depth = 0;
  const normalize = (path: string | undefined) => (path ?? '').replace(/\/+$/, '');
</script>
<ul class="sl-sidebar-list" class:sl-sidebar-nested={depth > 0}>
  {#each items as item}
    <li><a class:sl-current={normalize(item.path) === normalize(currentPath)} href={item.path} aria-current={normalize(item.path) === normalize(currentPath) ? 'page' : undefined}><span>{item.title}</span></a>{#if item.children?.length}<svelte:self items={item.children} {currentPath} depth={depth + 1} />{/if}</li>
  {/each}
</ul>
