import { useState } from 'react';

import { engine } from '@/core/engine';
import { useT } from '@/core/hooks';
import { attempt, notify } from '@/core/store';
import { Field, Row, Screen, Section, useClose } from '@/ui/kit';
import { isIOS } from '@/ui/theme';

const PRESET = 'https://raw.githubusercontent.com/ACL4SSR/ACL4SSR/master/Clash/config/ACL4SSR_Online_Full.ini';

/** Imports every rule-set of an ACL4SSR / subconverter `.ini` (a URL or its text). */
export default function ImportAcl() {
  const t = useT();
  const close = useClose();
  const [source, setSource] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  const run = async () => {
    if (source.trim() === '') {
      setError(t('err.required'));
      return;
    }
    setBusy(true);
    const count = await attempt(engine.importAclIni(source.trim()));
    setBusy(false);
    if (count === undefined) return;
    notify('success', t('acl.imported', [count]));
    close();
  };

  return (
    <Screen
      title={t('btn.import_acl')}
      modal
      actions={[
        {
          icon: 'check',
          label: t('btn.import'),
          text: t('btn.import'),
          primary: true,
          disabled: busy,
          onPress: () => void run(),
        },
      ]}>
      <Section header={t('acl.title')} footer={t('acl.desc')}>
        <Field
          testID="acl-source"
          label={t('rules.source')}
          value={source}
          onChange={(v) => {
            setSource(v);
            setError(null);
          }}
          placeholder="https://…/config.ini"
          multiline
          monospace
          autoFocus
          error={error}
        />
        <Row
          title={t('acl.preset')}
          icon={{ name: 'link', color: isIOS ? '#007AFF' : undefined }}
          onPress={() => {
            setSource(PRESET);
            setError(null);
          }}
        />
      </Section>
    </Screen>
  );
}
