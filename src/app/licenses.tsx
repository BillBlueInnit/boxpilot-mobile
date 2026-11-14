import { Linking, Text, View } from 'react-native';

import licenses from '../../assets/licenses.json';
import { useT } from '@/core/hooks';
import { GUTTER, Row, Screen, Section } from '@/ui/kit';
import { isIOS, usePalette } from '@/ui/theme';

function License({ title, text }: { title: string; text: string }) {
  const palette = usePalette();
  return (
    <View style={{ marginHorizontal: GUTTER + 16, marginTop: 24 }}>
      <Text style={{ fontSize: 17, fontWeight: '600', color: palette.text }}>{title}</Text>
      <Text
        selectable
        style={{ fontSize: 12, lineHeight: 17, color: palette.secondary, marginTop: 8, fontFamily: isIOS ? 'Menlo' : 'monospace' }}>
        {text}
      </Text>
    </View>
  );
}

/** The app's licence, the embedded core's, and where the source is. */
export default function Licenses() {
  const t = useT();
  return (
    <Screen title={t('set.licenses')}>
      <Section footer={t('set.licenses_desc')}>
        <Row
          title="BoxPilot"
          value="MIT"
          chevron
          onPress={() => void Linking.openURL('https://github.com/BillBlueInnit/boxpilot-mobile')}
        />
        <Row
          title="sing-box"
          value="GPL-3.0-or-later"
          chevron
          onPress={() => void Linking.openURL('https://github.com/SagerNet/sing-box')}
        />
        <Row
          title="GNU General Public License v3.0"
          chevron
          onPress={() => void Linking.openURL('https://www.gnu.org/licenses/gpl-3.0.html')}
        />
      </Section>
      <License title="BoxPilot" text={licenses.boxpilot} />
      <License title="sing-box" text={licenses.core} />
    </Screen>
  );
}
