import * as Clipboard from 'expo-clipboard';
import { useEffect, useRef, useState } from 'react';
import { FlatList, Pressable, Text, View } from 'react-native';

import { type LogEntry, engine } from '@/core/engine';
import { formatClock } from '@/core/format';
import { useT } from '@/core/hooks';
import { notify, settingOf, updateSettings, useStore } from '@/core/store';
import { EmptyState, GUTTER, Screen, Segmented } from '@/ui/kit';
import { isIOS, usePalette } from '@/ui/theme';

const LEVELS = ['TRACE', 'DEBUG', 'INFO', 'WARN', 'ERROR'];
/** Filter steps: all, info and up, warnings and up, errors. */
const FLOORS = [0, 2, 3, 4];

/** Core and app messages. Tap a line to read it in full; long-press to copy it. */
export default function LogsPage() {
  const t = useT();
  const palette = usePalette();
  const revision = useStore((s) => s.logRevision);
  const recording = useStore((s) => settingOf(s.settings, 'record_logs', true));
  const [lines, setLines] = useState<LogEntry[]>([]);
  const [floor, setFloor] = useState(0);
  const [filter, setFilter] = useState('');
  const [open, setOpen] = useState<number | null>(null);
  const loading = useRef(false);

  useEffect(() => {
    if (loading.current) return;
    loading.current = true;
    void engine
      .logs()
      .then(setLines, () => {})
      .finally(() => {
        loading.current = false;
      });
  }, [revision]);

  const f = filter.toLowerCase();
  // Newest first: the line that explains a failure is the latest one.
  const shown = lines
    .map((line, index) => ({ line, index }))
    .filter(({ line }) => line.level >= FLOORS[floor] && (f === '' || line.message.toLowerCase().includes(f)))
    .reverse();

  const levelColor = (level: number) => (level >= 4 ? palette.bad : level === 3 ? palette.fair : palette.secondary);
  const copy = (line: LogEntry) => {
    void Clipboard.setStringAsync(`${formatClock(line.time)} ${LEVELS[line.level] ?? ''} ${line.message}`);
    notify('success', t('logs.copied'));
  };

  return (
    <Screen
      title={t('nav.logs')}
      scroll={false}
      search={{ placeholder: t('logs.search'), onChange: setFilter }}
      actions={[
        {
          icon: recording ? 'stop' : 'record',
          label: recording ? t('btn.record_stop') : t('btn.record_start'),
          onPress: () => updateSettings({ record_logs: !recording }),
        },
        {
          icon: 'clear',
          label: t('tip.clear'),
          onPress: () => {
            void engine.clearLogs().then(() => setLines([]));
            setOpen(null);
          },
        },
      ]}>
      <FlatList
        data={shown}
        keyExtractor={(item) => String(item.index)}
        contentInsetAdjustmentBehavior="automatic"
        keyboardDismissMode="on-drag"
        contentContainerStyle={{ paddingBottom: 32 }}
        ListHeaderComponent={
          <View style={{ marginHorizontal: GUTTER, marginTop: 8, marginBottom: 8 }}>
            <Segmented labels={[t('logs.all'), 'INFO', 'WARN', 'ERROR']} index={floor} onChange={setFloor} />
            {recording ? null : (
              <Text style={{ fontSize: 13, color: palette.secondary, marginTop: 8, marginLeft: 16 }}>
                {t('logs.stopped')}
              </Text>
            )}
          </View>
        }
        ListEmptyComponent={<EmptyState icon="logs" title={t('logs.empty')} message={t('logs.empty_hint')} />}
        renderItem={({ item: { line, index } }) => {
          const expanded = open === index;
          return (
            <Pressable
              onPress={() => setOpen(expanded ? null : index)}
              onLongPress={() => copy(line)}
              android_ripple={{ color: palette.fill }}
              style={{ paddingHorizontal: GUTTER + 4, paddingVertical: 5, backgroundColor: expanded ? palette.card : undefined }}>
              <Text
                numberOfLines={expanded ? undefined : 2}
                selectable={expanded}
                style={{ fontSize: 12, lineHeight: 17, fontFamily: isIOS ? 'Menlo' : 'monospace', color: palette.text }}>
                <Text style={{ color: palette.secondary }}>{formatClock(line.time)} </Text>
                <Text style={{ color: levelColor(line.level), fontWeight: '700' }}>{LEVELS[line.level] ?? ''} </Text>
                {line.message}
              </Text>
              {expanded ? (
                <Text onPress={() => copy(line)} style={{ fontSize: 13, fontWeight: '600', color: palette.accent, marginTop: 6 }}>
                  {t('btn.copy')}
                </Text>
              ) : null}
            </Pressable>
          );
        }}
      />
    </Screen>
  );
}
