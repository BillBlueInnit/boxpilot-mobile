import { useState } from 'react';

import Native from '../../modules/boxpilot-core';
import { engine } from '@/core/engine';
import { useT } from '@/core/hooks';
import { attempt, notify } from '@/core/store';
import { askConfirm } from '@/ui/dialogs';
import { Screen, Section, SwitchRow, useClose } from '@/ui/kit';
import { isIOS } from '@/ui/theme';

/** Chooses what a reset clears. The core is stopped and the app starts over. */
export default function Reset() {
  const t = useT();
  const close = useClose();
  const [parts, setParts] = useState({ settings: true, subscriptions: true, rule_sets: true, caches: true });
  const any = Object.values(parts).some(Boolean);

  const reset = async () => {
    const yes = await askConfirm({
      title: t('reset.title'),
      message: t('reset.body_mobile'),
      confirmLabel: t('btn.reset'),
      destructive: true,
    });
    if (!yes) return;
    const done = await attempt(engine.reset(parts).then(() => true));
    if (!done) return;
    // The engine holds deleted state after a reset; a fresh process starts clean.
    if (!isIOS) Native.exit();
    notify('info', t('reset.body_mobile'));
    close();
  };

  const row = (key: keyof typeof parts, title: string, subtitle: string) => (
    <SwitchRow
      title={t(title)}
      subtitle={t(subtitle)}
      value={parts[key]}
      onChange={(v) => setParts((p) => ({ ...p, [key]: v }))}
    />
  );

  return (
    <Screen
      title={t('reset.title')}
      modal
      actions={[
        {
          icon: 'check',
          label: t('btn.reset'),
          text: t('btn.reset'),
          primary: true,
          disabled: !any,
          onPress: () => void reset(),
        },
      ]}>
      <Section footer={t('reset.body_mobile')}>
        {row('settings', 'reset.settings', 'reset.settings_desc_mobile')}
        {row('subscriptions', 'reset.subs', 'reset.subs_desc')}
        {row('rule_sets', 'reset.rules', 'reset.rules_desc')}
        {row('caches', 'reset.caches', 'reset.caches_desc')}
      </Section>
    </Screen>
  );
}
