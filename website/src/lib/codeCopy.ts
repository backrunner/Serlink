import { copyCodeToClipboard } from 'svedocs/theme/headless';
import type { SvedocsTranslate } from 'svedocs/core';

export function codeCopy(node: HTMLElement, translate: SvedocsTranslate) {
  let t = translate;
  const copy = (event: MouseEvent) => {
    const button = (event.target as Element | null)?.closest<HTMLButtonElement>('button.sd-code-copy');
    if (!button || !node.contains(button)) return;
    const block = button.closest<HTMLElement>('.sd-code');
    const text = block?.dataset.copy ?? block?.querySelector('code')?.textContent ?? '';
    void copyCodeToClipboard(button, text, t('code.copied'), t('code.copy'));
  };
  node.addEventListener('click', copy);
  return {
    update(translate: SvedocsTranslate) { t = translate; },
    destroy() { node.removeEventListener('click', copy); },
  };
}
