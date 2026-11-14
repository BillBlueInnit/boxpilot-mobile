import { useEffect, useState } from 'react';

import { engine } from '@/core/engine';
import { useT } from '@/core/hooks';
import { attempt, notify } from '@/core/store';
import { Field, Screen, Section, useClose } from '@/ui/kit';

/**
 * The custom rules, one `TYPE,VALUE,TARGET` per line. They live in
 * `CustomRule.list` in the data folder, so they are saved through the engine,
 * never as a settings field (the file wins at start-up).
 */
export default function CustomRules() {
  const t = useT();
  const close = useClose();
  const [text, setText] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    void engine.customRules().then(setText, () => setText(''));
  }, []);

  const save = async () => {
    if (text == null) return;
    setSaving(true);
    const ok = await attempt(engine.setCustomRules(text).then(() => true));
    setSaving(false);
    if (!ok) return;
    notify('success', t('rules.applied'));
    close();
  };

  return (
    <Screen
      title={t('rules.custom')}
      modal
      actions={[
        {
          icon: 'check',
          label: t('btn.save'),
          text: t('btn.save'),
          primary: true,
          disabled: saving || text == null,
          onPress: () => void save(),
        },
      ]}>
      <Section footer={t('rules.custom_help')}>
        {text == null ? null : (
          <Field
            testID="custom-rules-text"
            label={t('rules.custom')}
            value={text}
            onChange={setText}
            placeholder={'DOMAIN-SUFFIX,openai.com,proxy\nGEOSITE,netflix,proxy\nIP-CIDR,192.168.0.0/16,direct'}
            multiline
            monospace
          />
        )}
      </Section>
    </Screen>
  );
}
