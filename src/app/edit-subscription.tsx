import * as DocumentPicker from 'expo-document-picker';
import { File } from 'expo-file-system';
import { useLocalSearchParams } from 'expo-router';
import { useState } from 'react';
import { View } from 'react-native';

import { type Subscription, blankSubscription, engine } from '@/core/engine';
import { useT } from '@/core/hooks';
import { attempt, notify, settingOf, useStore } from '@/core/store';
import { ChoiceRow, Field, GUTTER, Row, Screen, Section, Segmented, SwitchRow, useClose } from '@/ui/kit';
import { isIOS } from '@/ui/theme';

/** Largest file taken as subscription content. */
const MAX_FILE = 8 << 20;

function validRegex(text: string): boolean {
  if (text === '') return true;
  try {
    new RegExp(text);
    return true;
  } catch {
    return false;
  }
}

/**
 * Adds or edits a subscription. `id` edits; `url` and `name` prefill a new one
 * (a provider's import link, or a URL from the clipboard).
 */
export default function EditSubscription() {
  const t = useT();
  const close = useClose();
  const params = useLocalSearchParams<{ id?: string; url?: string; name?: string }>();
  const existing = useStore((s) => s.subscriptions.find((x) => x.id === params.id));
  const settings = useStore((s) => s.settings);
  const isNew = !existing;

  const [sub, setSub] = useState<Subscription>(
    () =>
      existing ?? {
        ...blankSubscription(settingOf(settings, 'sub_default_interval_min', 720)),
        url: params.url ?? '',
        name: params.name ?? '',
      },
  );
  const [remote, setRemote] = useState(existing ? existing.url !== '' : true);
  const [content, setContent] = useState('');
  const [hours, setHours] = useState(String(Math.floor(sub.interval_min / 60)));
  const [saving, setSaving] = useState(false);
  const [checked, setChecked] = useState(false);
  const patch = (changes: Partial<Subscription>) => setSub((s) => ({ ...s, ...changes }));

  const errors = {
    url: remote && !/^https?:\/\/\S+$/.test(sub.url.trim()) ? t('editor.err_url') : null,
    content: !remote && isNew && content.trim() === '' ? t('editor.err_content') : null,
    interval: !/^\d+$/.test(hours.trim()) ? t('editor.err_interval') : null,
    include: validRegex(sub.include.trim()) ? null : t('err.invalid'),
    exclude: validRegex(sub.exclude.trim()) ? null : t('err.invalid'),
  };
  const shown = (e: string | null) => (checked ? e : null);

  /** A Clash YAML, sing-box JSON or list of share links saved as a file. */
  const chooseFile = async () => {
    const picked = await DocumentPicker.getDocumentAsync({ copyToCacheDirectory: true });
    const asset = picked.assets?.[0];
    if (!asset) return;
    if ((asset.size ?? 0) > MAX_FILE) {
      notify('error', t('err.file_too_large'));
      return;
    }
    try {
      setContent(await new File(asset.uri).text());
      if (sub.name.trim() === '') patch({ name: asset.name.replace(/\.[^.]+$/, '') });
    } catch (e) {
      notify('error', String(e));
    }
  };

  const save = async () => {
    setChecked(true);
    if (Object.values(errors).some(Boolean)) return;
    setSaving(true);
    const next: Subscription = {
      ...sub,
      name: sub.name.trim(),
      url: remote ? sub.url.trim() : '',
      auto_update: remote && sub.auto_update,
      interval_min: Number(hours.trim()) * 60,
      update_on_start: remote && sub.update_on_start,
      user_agent: sub.user_agent.trim(),
      include: sub.include.trim(),
      exclude: sub.exclude.trim(),
    };
    const text = !remote && content.trim() !== '' ? content : undefined;
    const ok = await attempt(
      isNew ? engine.addSubscription(next, text).then(() => true) : engine.saveSubscription(next, text).then(() => true),
    );
    setSaving(false);
    if (ok) close();
  };

  const defaultUa = settingOf(settings, 'sub_user_agent', 'clash.meta');
  return (
    <Screen
      title={isNew ? t('subs.add_title') : t('editor.edit_title')}
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
      {isNew ? (
        <View style={{ marginHorizontal: GUTTER, marginTop: 16 }}>
          <Segmented
            labels={[t('editor.remote'), t('editor.paste')]}
            index={remote ? 0 : 1}
            onChange={(i) => setRemote(i === 0)}
          />
        </View>
      ) : null}
      <Section header={t('subs.source')} footer={remote ? t('editor.url_hint') : undefined}>
        {remote ? (
          <Field
            testID="subscription-url"
            label={t('editor.url')}
            value={sub.url}
            onChange={(url) => patch({ url })}
            placeholder="https://"
            keyboardType="url"
            autoFocus={isNew && !params.url}
            error={shown(errors.url)}
          />
        ) : (
          <Field
            label={t('editor.content')}
            value={content}
            onChange={setContent}
            placeholder={t('editor.content_ph')}
            multiline
            monospace
            error={shown(errors.content)}
          />
        )}
        {remote ? null : (
          <Row
            title={t('subs.choose_file')}
            icon={{ name: 'folder', color: isIOS ? '#007AFF' : undefined }}
            onPress={() => void chooseFile()}
          />
        )}
        <Field
          testID="subscription-name"
          label={t('editor.name')}
          value={sub.name}
          onChange={(name) => patch({ name })}
          placeholder={t('editor.name_ph')}
        />
      </Section>
      {remote ? (
        <Section header={t('subs.updates')}>
          <Field
            label={t('editor.interval')}
            value={hours}
            onChange={setHours}
            keyboardType="number-pad"
            helper={t('editor.interval_hint')}
            error={shown(errors.interval)}
          />
          <SwitchRow
            title={t('editor.auto_update')}
            subtitle={t('editor.auto_update_desc')}
            value={sub.auto_update}
            onChange={(auto_update) => patch({ auto_update })}
          />
          <SwitchRow
            title={t('editor.update_start')}
            subtitle={t('editor.update_start_desc_mobile')}
            value={sub.update_on_start}
            onChange={(update_on_start) => patch({ update_on_start })}
          />
          <ChoiceRow
            title={t('editor.via')}
            message={t('editor.via_hint')}
            value={sub.update_via}
            options={[
              { value: 'auto' as const, label: t('via.auto') },
              { value: 'direct' as const, label: t('via.direct') },
              { value: 'proxy' as const, label: t('via.proxy') },
            ]}
            onChange={(update_via) => patch({ update_via })}
          />
          <Field
            label={t('editor.ua')}
            value={sub.user_agent}
            onChange={(user_agent) => patch({ user_agent })}
            placeholder={t('editor.ua_ph', [defaultUa])}
          />
        </Section>
      ) : null}
      <Section header={t('subs.filters')}>
        <Field
          label={t('editor.include')}
          value={sub.include}
          onChange={(include) => patch({ include })}
          placeholder="香港|HK|Hong Kong"
          error={shown(errors.include)}
        />
        <Field
          label={t('editor.exclude')}
          value={sub.exclude}
          onChange={(exclude) => patch({ exclude })}
          placeholder="过期|剩余|Expire"
          error={shown(errors.exclude)}
        />
      </Section>
    </Screen>
  );
}
