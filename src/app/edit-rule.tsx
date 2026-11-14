import * as DocumentPicker from 'expo-document-picker';
import { Directory, File } from 'expo-file-system';
import { useLocalSearchParams, useRouter } from 'expo-router';
import { useState } from 'react';

import { RULE_FORMATS, type RuleFormat, type RuleProvider, blankRuleProvider, engine } from '@/core/engine';
import { outboundLabel } from '@/core/format';
import { useT } from '@/core/hooks';
import { attempt, notify, useStore } from '@/core/store';
import { ChoiceRow, Field, Row, Screen, Section, SwitchRow, useClose } from '@/ui/kit';
import { isIOS } from '@/ui/theme';

const isUrl = (text: string) => /^https?:\/\/\S+$/.test(text);

/** Adds or edits a rule-set (`id` edits). */
export default function EditRule() {
  const t = useT();
  const router = useRouter();
  const close = useClose();
  const { id } = useLocalSearchParams<{ id?: string }>();
  const existing = useStore((s) => s.ruleProviders.find((p) => p.id === id));
  const dataDir = useStore((s) => s.host?.dataDir ?? '');
  const isNew = !existing;

  const [rule, setRule] = useState<RuleProvider>(() => existing ?? blankRuleProvider());
  const [hours, setHours] = useState(String(rule.interval_hours));
  const [checked, setChecked] = useState(false);
  const [saving, setSaving] = useState(false);
  const patch = (changes: Partial<RuleProvider>) => setRule((r) => ({ ...r, ...changes }));

  const source = rule.source.trim();
  const errors = {
    // A file the app copied in (see chooseFile) is an absolute path.
    source: isUrl(source) || source.startsWith('/') ? null : t('rules.err_source'),
    interval: /^\d+$/.test(hours.trim()) ? null : t('editor.err_interval'),
  };
  const shown = (e: string | null) => (checked ? e : null);

  /** A rule-set file from the device: copied into the app's data, where the core can read it. */
  const chooseFile = async () => {
    const picked = await DocumentPicker.getDocumentAsync({ copyToCacheDirectory: true });
    const asset = picked.assets?.[0];
    if (!asset) return;
    try {
      const folder = new Directory(`file://${dataDir}`, 'imported');
      if (!folder.exists) folder.create({ intermediates: true });
      const target = new File(folder, asset.name);
      if (target.exists) target.delete();
      new File(asset.uri).copy(target);
      patch({
        source: `${dataDir}/imported/${asset.name}`,
        name: rule.name.trim() === '' ? asset.name.replace(/\.[^.]+$/, '') : rule.name,
      });
    } catch (e) {
      notify('error', String(e));
    }
  };

  const save = async () => {
    setChecked(true);
    if (Object.values(errors).some(Boolean)) return;
    setSaving(true);
    const next: RuleProvider = {
      ...rule,
      source,
      name: rule.name.trim() || source.split(/[\\/]/).pop()?.replace(/\.[^.]+$/, '') || source,
      interval_hours: Number(hours.trim()),
      own_group: rule.own_group && rule.target !== 'reject',
    };
    const saved = await attempt(engine.saveRuleProvider(next));
    setSaving(false);
    if (saved !== undefined) close();
  };

  const targets = ['proxy', 'direct', 'reject'];
  // A target the desktop set to a group or node name stays selectable.
  if (!targets.includes(rule.target)) targets.push(rule.target);

  return (
    <Screen
      title={isNew ? t('rules.add_title') : t('rules.edit_title')}
      modal
      actions={[
        {
          icon: 'check',
          label: isNew ? t('btn.add') : t('btn.save'),
          text: isNew ? t('btn.add') : t('btn.save'),
          primary: true,
          disabled: saving,
          onPress: () => void save(),
        },
      ]}>
      <Section header={t('rules.source')} footer={t('rules.source_hint')}>
        <Field
          testID="rule-source"
          label={t('rules.source')}
          value={rule.source}
          onChange={(v) => patch({ source: v })}
          placeholder="https://"
          keyboardType="url"
          autoFocus={isNew}
          error={shown(errors.source)}
        />
        <Row
          title={t('subs.choose_file')}
          icon={{ name: 'folder', color: isIOS ? '#007AFF' : undefined }}
          onPress={() => void chooseFile()}
        />
        <Field
          label={t('editor.name')}
          value={rule.name}
          onChange={(name) => patch({ name })}
          placeholder={t('editor.name_ph')}
        />
      </Section>

      <Section footer={t('rules.target_hint')}>
        <ChoiceRow
          title={t('rules.format')}
          value={rule.format}
          options={(Object.keys(RULE_FORMATS) as RuleFormat[]).map((f) => ({
            value: f,
            label: f === 'auto' ? t('rules.format_auto') : RULE_FORMATS[f],
          }))}
          onChange={(format) => patch({ format })}
        />
        <ChoiceRow
          title={t('rules.target')}
          message={t('rules.target_hint')}
          value={rule.target}
          options={targets.map((v) => ({
            value: v,
            label: v === 'proxy' || v === 'direct' || v === 'reject' ? t(`target.${v}`) : outboundLabel(v),
          }))}
          onChange={(target) => patch({ target })}
        />
      </Section>

      {rule.target !== 'reject' ? (
        <Section>
          <SwitchRow
            title={t('rules.own_group_mobile')}
            subtitle={t('rules.own_group_desc_mobile')}
            value={rule.own_group}
            onChange={(own_group) => patch({ own_group })}
          />
        </Section>
      ) : null}

      <Section footer={t('editor.interval_hint')}>
        <Field
          label={t('editor.interval')}
          value={hours}
          onChange={setHours}
          keyboardType="number-pad"
          error={shown(errors.interval)}
        />
      </Section>

      {existing ? (
        <Section>
          <Row
            title={t('btn.edit_file')}
            icon={{ name: 'edit', color: isIOS ? '#8E8E93' : undefined }}
            chevron
            onPress={() => router.push({ pathname: '/rule-text', params: { id: existing.id } })}
          />
        </Section>
      ) : null}
    </Screen>
  );
}
