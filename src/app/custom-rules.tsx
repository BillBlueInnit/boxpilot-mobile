import { useRouter } from 'expo-router';
import { useCallback, useEffect, useMemo, useState } from 'react';
import { Pressable, Text, TextInput, View } from 'react-native';

import {
  CUSTOM_RULE_KINDS,
  type CustomRule,
  type CustomRuleGroup,
  type CustomRuleKind,
  engine,
} from '@/core/engine';
import { outboundLabel } from '@/core/format';
import { useT } from '@/core/hooks';
import {
  OWN_GROUP_VALUE,
  extraTargetGroups,
  kindLabel,
  kindPlaceholder,
  providerTargetLabel,
  targetLabel,
  targetTint,
} from '@/core/rules-ui';
import { attempt, focusProxyGroup, notify, useStore } from '@/core/store';
import { configureLayoutMotion, lightHaptic, selectionHaptic } from '@/ui/anim';
import { askChoice, askConfirm, askText } from '@/ui/dialogs';
import { Card, Chip, EmptyState, Field, GUTTER, Row, Screen, Section, Segmented, Toggle } from '@/ui/kit';
import { isIOS, usePalette } from '@/ui/theme';

type Mode = 'visual' | 'text';

const UNGROUPED_ID = '__ungrouped__';

/**
 * Custom rules backed by `CustomRule.list` plus named custom rule groups.
 * Visual mode keeps Ungrouped exceptions on top, followed by user-named groups
 * whose own node groups appear on Proxies. Text mode edits `CustomRule.list`
 * directly with an explicit Save action.
 */
export default function CustomRules() {
  const t = useT();
  const router = useRouter();
  const palette = usePalette();
  const groups = useStore((s) => s.groups);
  const providers = useStore((s) => s.ruleProviders);
  const storeCustomGroups = useStore((s) => s.customRuleGroups);

  const [mode, setMode] = useState<Mode>('visual');
  const [rules, setRules] = useState<CustomRule[]>([]);
  const [customGroups, setCustomGroups] = useState<CustomRuleGroup[]>(storeCustomGroups);
  const [text, setText] = useState<string>('');
  const [loaded, setLoaded] = useState(false);
  const [saving, setSaving] = useState(false);

  // Compact quick-add bar state
  const [kind, setKind] = useState<CustomRuleKind>('DOMAIN-SUFFIX');
  const [value, setValue] = useState('');
  const [target, setTarget] = useState('proxy');
  const [quickGroupId, setQuickGroupId] = useState<string | null>(null);

  const reload = useCallback(async () => {
    const [parsed, raw, cgroups] = await Promise.all([
      engine.customRulesParsed().catch(() => [] as CustomRule[]),
      engine.customRules().catch(() => ''),
      engine.customRuleGroups().catch(() => [] as CustomRuleGroup[]),
    ]);
    setRules(parsed);
    setText(raw);
    setCustomGroups(cgroups);
    setQuickGroupId((prev) => (prev && cgroups.some((g) => g.id === prev) ? prev : null));
    setLoaded(true);
  }, []);

  useEffect(() => {
    let alive = true;
    void Promise.all([
      engine.customRulesParsed().catch(() => [] as CustomRule[]),
      engine.customRules().catch(() => ''),
      engine.customRuleGroups().catch(() => [] as CustomRuleGroup[]),
    ]).then(([parsed, raw, cgroups]) => {
      if (!alive) return;
      setRules(parsed);
      setText(raw);
      setCustomGroups(cgroups);
      setLoaded(true);
    });
    return () => {
      alive = false;
    };
  }, []);

  const targetOptions = useMemo(() => {
    const extras = extraTargetGroups(groups, providers, customGroups);
    return [
      { value: 'proxy', label: t('target.proxy') },
      { value: 'direct', label: t('target.direct') },
      { value: 'reject', label: t('target.reject') },
      ...extras.map((g) => ({ value: g, label: outboundLabel(g) })),
    ];
  }, [groups, providers, customGroups, t]);

  const kindOptions = CUSTOM_RULE_KINDS.map((k) => ({ value: k, label: kindLabel(k) }));

  const selectedQuickGroup = customGroups.find((g) => g.id === quickGroupId) ?? null;

  const createGroup = async () => {
    const name = await askText({
      title: t('rules.new_group_mobile'),
      placeholder: t('rules.group_name_ph_mobile'),
      confirmLabel: t('btn.add'),
      validate: (v) => (v.trim() === '' ? t('err.empty') : null),
    });
    if (name == null) return;
    lightHaptic();
    configureLayoutMotion();
    const id = await attempt(engine.createCustomRuleGroup(name.trim(), 'proxy', true));
    if (id !== undefined) {
      await reload();
    }
  };

  const addQuick = async () => {
    if (value.trim() === '' || saving) return;
    lightHaptic();
    setSaving(true);
    const added = await attempt(
      engine.addStructuredCustomRuleInGroup(kind, value, selectedQuickGroup ? selectedQuickGroup.target : target, quickGroupId),
    );
    setSaving(false);
    if (added === undefined) return;
    if (added) {
      setValue('');
      configureLayoutMotion();
      notify('success', t('rules.custom_added'));
    } else {
      notify('info', t('rules.custom_exists'));
    }
    await reload();
  };

  const pickQuickKind = async () => {
    const picked = await askChoice({
      title: t('rules.custom_type'),
      options: kindOptions,
      value: kind,
    });
    if (picked) {
      selectionHaptic();
      setKind(picked);
    }
  };

  const pickQuickTarget = async () => {
    const picked = await askChoice({
      title: t('rules.target'),
      options: targetOptions,
      value: target,
    });
    if (picked) {
      selectionHaptic();
      setTarget(picked);
    }
  };

  const pickQuickGroup = async () => {
    const picked = await askChoice({
      title: t('rules.move_to_group_mobile'),
      options: [
        { value: UNGROUPED_ID, label: t('rules.ungrouped_mobile') },
        ...customGroups.map((g) => ({ value: g.id, label: g.name })),
      ],
      value: quickGroupId ?? UNGROUPED_ID,
    });
    if (picked !== undefined) {
      selectionHaptic();
      setQuickGroupId(picked === UNGROUPED_ID ? null : picked);
    }
  };

  const saveText = async () => {
    if (saving) return;
    setSaving(true);
    const ok = await attempt(engine.setCustomRules(text).then(() => true));
    setSaving(false);
    if (!ok) return;
    notify('success', t('rules.applied'));
    await reload();
  };

  const jumpToProxyGroup = async (g: CustomRuleGroup) => {
    const tag = (await engine.customRuleGroupTagFor(g.id).catch(() => null)) ?? g.name;
    focusProxyGroup(tag);
    router.navigate('/(tabs)/proxies');
  };

  const pickGroupTarget = async (g: CustomRuleGroup) => {
    const extras = extraTargetGroups(groups, providers, customGroups).filter((n) => n !== g.name);
    const current = g.own_group && g.target !== 'reject' ? OWN_GROUP_VALUE : g.target;
    const options = [
      { value: 'proxy', label: t('target.proxy') },
      { value: 'direct', label: t('target.direct') },
      { value: 'reject', label: t('target.reject') },
      { value: OWN_GROUP_VALUE, label: t('rules.own_group_option') },
      ...extras.map((n) => ({ value: n, label: outboundLabel(n) })),
    ];
    if (!options.some((o) => o.value === current)) {
      options.push({ value: current, label: outboundLabel(current) });
    }
    const picked = await askChoice({
      title: g.name,
      options,
      value: current,
    });
    if (picked === undefined || picked === current) return;
    selectionHaptic();
    if (picked === OWN_GROUP_VALUE) {
      const baseTarget = g.target === 'reject' ? 'proxy' : g.target;
      await attempt(engine.setCustomRuleGroupTarget(g.id, baseTarget, true));
    } else {
      await attempt(engine.setCustomRuleGroupTarget(g.id, picked, false));
    }
    await reload();
  };

  const groupMenu = async (g: CustomRuleGroup) => {
    const hasOwnGroup = g.own_group && g.target !== 'reject';
    const picked = await askChoice({
      title: g.name,
      message: providerTargetLabel(g),
      menu: true,
      options: [
        ...(hasOwnGroup ? [{ value: 'proxies', label: t('rules.goto_proxies') }] : []),
        { value: 'target', label: `${t('rules.target')}: ${providerTargetLabel(g)}` },
        { value: 'rename', label: t('rules.rename_group_mobile') },
        { value: 'up', label: t('tip.move_up') },
        { value: 'down', label: t('tip.move_down') },
        { value: 'delete', label: t('btn.delete'), destructive: true },
      ],
    });
    if (picked === 'proxies') void jumpToProxyGroup(g);
    if (picked === 'target') void pickGroupTarget(g);
    if (picked === 'rename') {
      const next = await askText({
        title: t('rules.rename_group_mobile'),
        initial: g.name,
        confirmLabel: t('btn.save'),
        validate: (v) => (v.trim() === '' ? t('err.empty') : null),
      });
      if (next != null && next.trim() !== g.name) {
        await attempt(engine.renameCustomRuleGroup(g.id, next.trim()));
        await reload();
      }
    }
    if (picked === 'up') {
      configureLayoutMotion();
      await attempt(engine.moveCustomRuleGroup(g.id, -1));
      await reload();
    }
    if (picked === 'down') {
      configureLayoutMotion();
      await attempt(engine.moveCustomRuleGroup(g.id, 1));
      await reload();
    }
    if (picked === 'delete') {
      const yes = await askConfirm({
        title: t('btn.delete'),
        message: t('rules.delete_group_body_mobile', [g.name]),
        confirmLabel: t('btn.delete'),
        destructive: true,
      });
      if (yes) {
        configureLayoutMotion();
        await attempt(engine.removeCustomRuleGroup(g.id));
        await reload();
      }
    }
  };

  const moveRuleToGroup = async (r: CustomRule) => {
    const currentGroup = r.group ? customGroups.find((g) => g.name.toLowerCase() === r.group?.toLowerCase()) : null;
    const picked = await askChoice({
      title: t('rules.move_to_group_mobile'),
      options: [
        { value: UNGROUPED_ID, label: t('rules.ungrouped_mobile') },
        ...customGroups.map((g) => ({ value: g.id, label: g.name })),
      ],
      value: currentGroup?.id ?? UNGROUPED_ID,
    });
    if (picked === undefined) return;
    const targetId = picked === UNGROUPED_ID ? null : picked;
    if (targetId === (currentGroup?.id ?? null)) return;
    selectionHaptic();
    configureLayoutMotion();
    const ok = await attempt(engine.moveCustomRuleToGroup(r.line_index, targetId).then(() => true));
    if (ok) await reload();
  };

  const changeTarget = async (r: CustomRule) => {
    if (!r.kind) return;
    const options = [...targetOptions];
    if (!options.some((o) => o.value === r.target)) {
      options.push({ value: r.target, label: targetLabel(r.target) });
    }
    const picked = await askChoice({
      title: r.value,
      options,
      value: r.target,
    });
    if (!picked || picked === r.target) return;
    selectionHaptic();
    const ok = await attempt(engine.updateCustomRule(r.line_index, r.kind, r.value, picked, r.enabled).then(() => true));
    if (ok) await reload();
  };

  const editRule = async (r: CustomRule, inGroup: boolean) => {
    const currentKind: CustomRuleKind = r.kind ?? 'DOMAIN-SUFFIX';
    const pickedKind = await askChoice({
      title: t('rules.custom_type'),
      options: kindOptions,
      value: currentKind,
    });
    if (!pickedKind) return;
    const nextValue = await askText({
      title: t('rules.custom_value'),
      initial: r.value,
      placeholder: kindPlaceholder(pickedKind),
      confirmLabel: t('btn.save'),
      validate: (v) => (v.trim() === '' ? t('err.empty') : null),
    });
    if (nextValue == null) return;
    let nextTarget = r.target || 'proxy';
    if (!inGroup) {
      const options = [...targetOptions];
      if (!options.some((o) => o.value === nextTarget)) {
        options.push({ value: nextTarget, label: targetLabel(nextTarget) });
      }
      const pickedTarget = await askChoice({
        title: t('rules.target'),
        options,
        value: nextTarget,
      });
      if (!pickedTarget) return;
      nextTarget = pickedTarget;
    }
    const ok = await attempt(
      engine.updateCustomRule(r.line_index, pickedKind, nextValue, nextTarget, r.enabled).then(() => true),
    );
    if (ok) await reload();
  };

  const ruleMenu = async (r: CustomRule, inGroup: boolean) => {
    const picked = await askChoice({
      title: r.error ? r.raw : r.value,
      message: r.error ?? (inGroup ? kindLabel(r.kind, r.kind_raw) : `${kindLabel(r.kind, r.kind_raw)} → ${targetLabel(r.target)}`),
      menu: true,
      options: [
        ...(customGroups.length > 0 && r.kind ? [{ value: 'move', label: t('rules.move_to_group_mobile') }] : []),
        ...(!inGroup && r.kind ? [{ value: 'target', label: t('rules.change_target_mobile') }] : []),
        { value: 'edit', label: t('btn.edit') },
        { value: 'up', label: t('tip.move_up') },
        { value: 'down', label: t('tip.move_down') },
        { value: 'delete', label: t('btn.delete'), destructive: true },
      ],
    });
    if (picked === 'move') void moveRuleToGroup(r);
    if (picked === 'target') void changeTarget(r);
    if (picked === 'edit') void editRule(r, inGroup);
    if (picked === 'up') {
      configureLayoutMotion();
      await attempt(engine.moveCustomRule(r.line_index, -1));
      await reload();
    }
    if (picked === 'down') {
      configureLayoutMotion();
      await attempt(engine.moveCustomRule(r.line_index, 1));
      await reload();
    }
    if (picked === 'delete') {
      const yes = await askConfirm({
        title: t('btn.delete'),
        message: r.raw,
        confirmLabel: t('btn.delete'),
        destructive: true,
      });
      if (yes) {
        configureLayoutMotion();
        await attempt(engine.removeCustomRule(r.line_index));
        await reload();
      }
    }
  };

  const switchMode = async (next: Mode) => {
    if (next === mode) return;
    selectionHaptic();
    configureLayoutMotion();
    if (next === 'visual') {
      await reload();
    }
    setMode(next);
  };

  // Partition rules into Ungrouped vs each named CustomRuleGroup.
  const groupNamesLower = new Set(customGroups.map((g) => g.name.toLowerCase()));
  const ungroupedRules = rules.filter((r) => !r.group || !groupNamesLower.has(r.group.toLowerCase()));
  const canAdd = value.trim() !== '' && !saving;

  const renderRuleRow = (r: CustomRule, inGroup: boolean) => {
    const tint = targetTint(palette, r.target);
    return (
      <Row
        key={r.line_index}
        title={r.error ? r.raw : r.value}
        subtitle={r.error ? r.error : `${kindLabel(r.kind, r.kind_raw)} · ${r.kind ?? r.kind_raw}`}
        subtitleLines={r.error ? 2 : 1}
        destructive={r.error != null}
        disabled={!r.enabled && r.error == null}
        onPress={() => void ruleMenu(r, inGroup)}
        trailing={
          <View style={{ flexDirection: 'row', alignItems: 'center', gap: 10 }}>
            {!inGroup && !r.error ? (
              <Pressable
                accessibilityRole="button"
                accessibilityLabel={`${t('rules.target')}: ${targetLabel(r.target)}`}
                hitSlop={6}
                onPress={() => void changeTarget(r)}
                style={{
                  paddingHorizontal: 10,
                  paddingVertical: 5,
                  borderRadius: 999,
                  backgroundColor: palette.fill,
                }}>
                <Text style={{ fontSize: 12, fontWeight: '600', color: r.enabled ? tint : palette.tertiary }}>
                  {targetLabel(r.target)}
                </Text>
              </Pressable>
            ) : null}
            <Toggle
              value={r.enabled}
              disabled={r.error != null}
              onChange={(v) => {
                selectionHaptic();
                void attempt(engine.setCustomRuleEnabled(r.line_index, v)).then(() => reload());
              }}
            />
          </View>
        }
      />
    );
  };

  return (
    <Screen
      title={t('rules.step_custom')}
      actions={
        mode === 'text'
          ? [
              {
                icon: 'check',
                label: t('btn.save'),
                text: t('btn.save'),
                primary: true,
                disabled: saving || !loaded,
                onPress: () => void saveText(),
              },
            ]
          : [
              {
                icon: 'add',
                label: t('rules.new_group_mobile'),
                onPress: () => void createGroup(),
              },
            ]
      }>
      <View style={{ marginHorizontal: GUTTER, marginTop: 12 }}>
        <Segmented
          labels={[t('rules.mode_visual'), t('rules.mode_text')]}
          index={mode === 'visual' ? 0 : 1}
          onChange={(i) => void switchMode(i === 0 ? 'visual' : 'text')}
        />
      </View>

      {mode === 'visual' ? (
        <>
          {/* Compact 2-line quick-add card */}
          <Card style={{ marginHorizontal: GUTTER, marginTop: 16, padding: 12 }}>
            <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8 }}>
              <TextInput
                testID="custom-rule-value"
                value={value}
                onChangeText={setValue}
                placeholder={kindPlaceholder(kind)}
                placeholderTextColor={palette.tertiary}
                autoCorrect={false}
                autoCapitalize="none"
                returnKeyType="done"
                onSubmitEditing={() => void addQuick()}
                style={{
                  flex: 1,
                  fontSize: isIOS ? 16 : 15,
                  color: palette.text,
                  backgroundColor: palette.fill,
                  borderRadius: 12,
                  paddingHorizontal: 12,
                  paddingVertical: isIOS ? 10 : 8,
                }}
              />
              <Pressable
                testID="custom-rule-add"
                accessibilityRole="button"
                accessibilityLabel={t('btn.add')}
                disabled={!canAdd}
                onPress={() => void addQuick()}
                style={({ pressed }) => ({
                  paddingHorizontal: 16,
                  paddingVertical: isIOS ? 10 : 9,
                  borderRadius: 12,
                  backgroundColor: canAdd ? palette.accent : palette.fill,
                  opacity: isIOS && pressed ? 0.78 : 1,
                })}>
                <Text
                  style={{
                    fontSize: 15,
                    fontWeight: '600',
                    color: canAdd ? palette.onAccent : palette.tertiary,
                  }}>
                  {t('btn.add')}
                </Text>
              </Pressable>
            </View>
            <View style={{ flexDirection: 'row', flexWrap: 'wrap', gap: 8, marginTop: 10 }}>
              <Chip icon="tune" label={kindLabel(kind)} onPress={() => void pickQuickKind()} />
              {customGroups.length > 0 ? (
                <Chip
                  icon="group"
                  label={selectedQuickGroup ? selectedQuickGroup.name : t('rules.ungrouped_mobile')}
                  onPress={() => void pickQuickGroup()}
                />
              ) : null}
              {!selectedQuickGroup ? (
                <Chip icon="direct" label={targetLabel(target)} onPress={() => void pickQuickTarget()} />
              ) : null}
            </View>
          </Card>

          {/* Ungrouped standalone exceptions (highest priority) */}
          {ungroupedRules.length > 0 ? (
            <Section
              header={
                customGroups.length > 0
                  ? `${t('rules.ungrouped_mobile')} · ${t('rules.ungrouped_badge_mobile')}`
                  : `${t('rules.step_custom')} (${ungroupedRules.length})`
              }
              footer={customGroups.length === 0 ? t('rules.custom_file_mobile') : undefined}>
              {ungroupedRules.map((r) => renderRuleRow(r, false))}
            </Section>
          ) : null}

          {/* User-named Custom Rule Groups */}
          {customGroups.map((g) => {
            const members = rules.filter((r) => r.group?.toLowerCase() === g.name.toLowerCase());
            const hasOwnGroup = g.own_group && g.target !== 'reject';
            const tint = targetTint(palette, g.target, hasOwnGroup);
            return (
              <Section key={g.id}>
                <Row
                  title={g.name}
                  subtitle={
                    members.length > 0
                      ? t('rules.count', [members.length])
                      : t('rules.group_empty_mobile')
                  }
                  icon={{ name: 'group', color: isIOS ? '#5856D6' : undefined }}
                  disabled={!g.enabled}
                  onPress={() => void groupMenu(g)}
                  trailing={
                    <View style={{ flexDirection: 'row', alignItems: 'center', gap: 10 }}>
                      <Pressable
                        accessibilityRole="button"
                        accessibilityLabel={`${t('rules.target')}: ${providerTargetLabel(g)}`}
                        hitSlop={6}
                        onPress={() => void pickGroupTarget(g)}
                        style={{
                          paddingHorizontal: 10,
                          paddingVertical: 5,
                          borderRadius: 999,
                          backgroundColor: palette.fill,
                        }}>
                        <Text style={{ fontSize: 12, fontWeight: '600', color: g.enabled ? tint : palette.tertiary }}>
                          {providerTargetLabel(g)}
                        </Text>
                      </Pressable>
                      <Toggle
                        value={g.enabled}
                        onChange={(v) => {
                          selectionHaptic();
                          void attempt(engine.setCustomRuleGroupEnabled(g.id, v)).then(() => reload());
                        }}
                      />
                    </View>
                  }
                />
                {members.map((r) => renderRuleRow(r, true))}
              </Section>
            );
          })}

          {rules.length === 0 && customGroups.length === 0 && loaded ? (
            <EmptyState
              icon="rules"
              title={t('rules.custom_empty')}
              message={t('rules.custom_empty_hint_mobile')}
            />
          ) : null}
        </>
      ) : (
        <Section footer={t('rules.custom_help')}>
          <Field
            testID="custom-rules-text"
            label={t('rules.step_custom')}
            value={text}
            onChange={setText}
            placeholder={'DOMAIN-SUFFIX,openai.com,proxy\nGEOSITE,netflix,proxy\nIP-CIDR,192.168.0.0/16,direct'}
            multiline
            monospace
          />
        </Section>
      )}
    </Screen>
  );
}
