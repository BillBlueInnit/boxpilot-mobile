import * as Clipboard from 'expo-clipboard';
import { useLocalSearchParams } from 'expo-router';
import { useState } from 'react';

import { engine } from '@/core/engine';
import { useT } from '@/core/hooks';
import { attempt, notify } from '@/core/store';
import { Field, Row, Screen, Section, useClose } from '@/ui/kit';
import { isIOS } from '@/ui/theme';

/**
 * Adds single nodes from share links (or anything a subscription can be).
 * They go into the "Local nodes" group. `text` prefills from the clipboard.
 */
export default function AddNode() {
  const t = useT();
  const close = useClose();
  const params = useLocalSearchParams<{ text?: string }>();
  const [text, setText] = useState(params.text ?? '');
  const [error, setError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  const save = async () => {
    if (text.trim() === '') {
      setError(t('local.err_empty'));
      return;
    }
    setSaving(true);
    const result = await attempt(engine.addLocalNodes(text));
    setSaving(false);
    if (!result) return;
    const skipped = result.skipped.length > 0 ? t('share.skipped', [result.skipped.length]) : '';
    notify('success', t('local.added', [result.added]) + skipped);
    close();
  };

  return (
    <Screen
      title={t('btn.add_node')}
      modal
      actions={[
        { icon: 'check', label: t('btn.add'), text: t('btn.add'), primary: true, disabled: saving, onPress: () => void save() },
      ]}>
      <Section footer={t('local.hint')}>
        <Field
          testID="node-links"
          label={t('local.links')}
          value={text}
          onChange={(v) => {
            setText(v);
            setError(null);
          }}
          placeholder="vless://…"
          multiline
          monospace
          autoFocus={!params.text}
          error={error}
        />
        <Row
          title={t('btn.paste')}
          icon={{ name: 'paste', color: isIOS ? '#007AFF' : undefined }}
          onPress={async () => {
            const clip = await Clipboard.getStringAsync();
            if (clip.trim() === '') notify('info', t('subs.clipboard_empty'));
            else setText((old) => (old.trim() === '' ? clip : `${old.trimEnd()}\n${clip}`));
          }}
        />
      </Section>
    </Screen>
  );
}
