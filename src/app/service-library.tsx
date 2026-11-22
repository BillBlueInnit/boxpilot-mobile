import { useCallback, useEffect, useState } from 'react';
import { Text } from 'react-native';

import { SERVICE_CATEGORIES, type ServicePreset, engine } from '@/core/engine';
import { useT } from '@/core/hooks';
import { attempt, useStore } from '@/core/store';
import { GUTTER, Screen, Section, SwitchRow } from '@/ui/kit';
import { usePalette } from '@/ui/theme';

/** Curated popular service rule-sets that can be enabled with a single switch. */
export default function ServiceLibrary() {
  const t = useT();
  const palette = usePalette();
  const providers = useStore((s) => s.ruleProviders);
  const [presets, setPresets] = useState<ServicePreset[]>([]);

  const reload = useCallback(() => {
    void engine.servicePresets().then(setPresets, () => setPresets([]));
  }, []);

  useEffect(() => {
    reload();
  }, [providers, reload]);

  const togglePreset = async (preset: ServicePreset, on: boolean) => {
    setPresets((list) => list.map((p) => (p.id === preset.id ? { ...p, added: on } : p)));
    if (on) {
      await attempt(engine.addServicePreset(preset.id));
    } else {
      await attempt(engine.removeServicePreset(preset.id));
    }
    reload();
  };

  return (
    <Screen title={t('rules.library_title')} modal dismissLabel={t('btn.close')}>
      <Text
        style={{
          fontSize: 13,
          lineHeight: 18,
          color: palette.secondary,
          marginHorizontal: GUTTER + 16,
          marginTop: 8,
        }}>
        {t('rules.library_desc')}
      </Text>

      {SERVICE_CATEGORIES.map((category) => {
        const items = presets.filter((p) => p.category === category);
        if (items.length === 0) return null;
        return (
          <Section key={category} header={t(`cat.${category}`)}>
            {items.map((preset) => (
              <SwitchRow
                key={preset.id}
                testID={`svc-${preset.id}`}
                title={t(`svc.${preset.id}`)}
                subtitle={t(`svc.${preset.id}_desc`)}
                value={preset.added}
                onChange={(on) => void togglePreset(preset, on)}
              />
            ))}
          </Section>
        );
      })}
    </Screen>
  );
}
