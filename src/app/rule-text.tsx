import { useLocalSearchParams } from 'expo-router';
import { useEffect, useState } from 'react';

import { engine } from '@/core/engine';
import { useT } from '@/core/hooks';
import { attempt, notify, useStore } from '@/core/store';
import { EmptyState, Field, Screen, Section, useClose } from '@/ui/kit';

/**
 * Edits a rule-set's text file in the app (phones have no system editor to
 * hand it to). A local source is converted again on save; a downloaded copy
 * is picked up by the core by itself.
 */
export default function RuleText() {
  const t = useT();
  const close = useClose();
  const { id } = useLocalSearchParams<{ id: string }>();
  const name = useStore((s) => s.ruleProviders.find((p) => p.id === id)?.name ?? '');
  const [file, setFile] = useState<{ text: string; local_source: boolean } | null | undefined>(undefined);
  const [text, setText] = useState('');
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    void engine.ruleProviderText(id).then(
      (f) => {
        setFile(f);
        setText(f?.text ?? '');
      },
      () => setFile(null),
    );
  }, [id]);

  const save = async () => {
    setSaving(true);
    const ok = await attempt(engine.saveRuleProviderText(id, text).then(() => true));
    setSaving(false);
    if (!ok) return;
    notify('success', t('rules.applied'));
    close();
  };

  return (
    <Screen
      title={name || t('btn.edit_file')}
      modal
      actions={
        file
          ? [
              {
                icon: 'check',
                label: t('btn.save'),
                text: t('btn.save'),
                primary: true,
                disabled: saving,
                onPress: () => void save(),
              },
            ]
          : []
      }>
      {file === undefined ? null : file === null ? (
        // Binary (.srs) or not downloaded yet.
        <EmptyState icon="logs" title={t('btn.edit_file')} message={t('tip.edit_file_binary')} />
      ) : (
        <Section footer={file.local_source ? t('rules.edit_local_mobile') : t('rules.edit_cached_mobile')}>
          <Field label={t('btn.edit_file')} value={text} onChange={setText} multiline monospace />
        </Section>
      )}
    </Screen>
  );
}
