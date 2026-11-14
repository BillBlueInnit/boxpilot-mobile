// The app's small adaptive kit. Each piece renders the platform's own idiom:
// on iOS the native navigation bar (large titles, toolbar buttons and menus,
// search), inset grouped lists, UISwitch and UISegmentedControl; on Android
// Material 3 through Paper (top app bar, filled cards, switches, segmented
// buttons).

import NativeSegmentedControl from '@react-native-segmented-control/segmented-control';
import { Stack, useRouter } from 'expo-router';
import { Children, type ComponentType, type ReactNode, isValidElement, useState } from 'react';
import {
  ActivityIndicator,
  type KeyboardTypeOptions,
  Pressable,
  RefreshControl,
  ScrollView,
  type StyleProp,
  StyleSheet,
  Switch,
  Text,
  TextInput,
  View,
  type ViewStyle,
} from 'react-native';
import {
  Appbar,
  Menu,
  Button as PaperButton,
  Switch as PaperSwitch,
  TextInput as PaperTextInput,
  Searchbar,
  SegmentedButtons,
} from 'react-native-paper';

import { tr } from '../i18n';
import { type Option, askChoice, askText } from './dialogs';
import { ICONS, Icon, type IconName } from './icons';
import { isIOS, usePalette } from './theme';

// The library's class typings predate React 19's.
const SegmentedControl = NativeSegmentedControl as unknown as ComponentType<{
  values: string[];
  selectedIndex: number;
  onChange: (event: { nativeEvent: { selectedSegmentIndex: number } }) => void;
}>;

// ------------------------------------------------------------------ screens

/**
 * Leaves the current page. A page opened by a link into a cold app has
 * nothing under it; then the dashboard takes its place.
 */
export function useClose() {
  const router = useRouter();
  return () => (router.canGoBack() ? router.back() : router.replace('/'));
}

export type MenuItem = {
  label: string;
  icon?: IconName;
  onPress: () => void;
  destructive?: boolean;
  /** Shows a checkmark (a current choice). */
  checked?: boolean;
};

/** A top bar action: a button, or a menu when `menu` is set. */
export type Action = {
  icon: IconName;
  label: string;
  onPress?: () => void;
  menu?: MenuItem[];
  /** iOS: show this text instead of the icon (Save, Done). */
  text?: string;
  /** The screen's main action (Save): emphasised. */
  primary?: boolean;
  disabled?: boolean;
};

type ScreenProps = {
  title: string;
  /** A tab's first page: large title on iOS, no back button on Android. */
  root?: boolean;
  /** Presented as a form: Cancel on the leading side. */
  modal?: boolean;
  actions?: Action[];
  search?: { placeholder: string; onChange: (text: string) => void };
  /** False when the child scrolls itself (a FlatList). */
  scroll?: boolean;
  onRefresh?: () => void;
  refreshing?: boolean;
  children: ReactNode;
};

/** A page with the platform's top bar. */
export function Screen(props: ScreenProps) {
  return isIOS ? <IosScreen {...props} /> : <AndroidScreen {...props} />;
}

function IosScreen({ title, root, modal, actions = [], search, scroll = true, onRefresh, refreshing, children }: ScreenProps) {
  const palette = usePalette();
  const close = useClose();
  return (
    <>
      <Stack.Screen
        options={{
          title,
          headerLargeTitle: root,
          headerSearchBarOptions: search
            ? {
                placeholder: search.placeholder,
                hideWhenScrolling: false,
                autoCapitalize: 'none',
                onChangeText: (e) => search.onChange(e.nativeEvent.text),
                onCancelButtonPress: () => search.onChange(''),
              }
            : undefined,
        }}
      />
      {modal ? (
        <Stack.Toolbar placement="left">
          <Stack.Toolbar.Button onPress={close}>{tr('btn.cancel')}</Stack.Toolbar.Button>
        </Stack.Toolbar>
      ) : null}
      {actions.length > 0 ? (
        <Stack.Toolbar placement="right">
          {actions.map((a) =>
            a.menu ? (
              <Stack.Toolbar.Menu key={a.label} icon={ICONS[a.icon].ios} accessibilityLabel={a.label}>
                {a.menu.map((m) => (
                  <Stack.Toolbar.MenuAction
                    key={m.label}
                    icon={m.icon ? ICONS[m.icon].ios : undefined}
                    isOn={m.checked}
                    destructive={m.destructive}
                    onPress={m.onPress}>
                    {m.label}
                  </Stack.Toolbar.MenuAction>
                ))}
              </Stack.Toolbar.Menu>
            ) : (
              <Stack.Toolbar.Button
                key={a.label}
                icon={a.text ? undefined : ICONS[a.icon].ios}
                accessibilityLabel={a.label}
                variant={a.primary ? 'done' : 'plain'}
                disabled={a.disabled}
                onPress={a.onPress}>
                {a.text}
              </Stack.Toolbar.Button>
            ),
          )}
        </Stack.Toolbar>
      ) : null}
      {scroll ? (
        <ScrollView
          style={{ flex: 1, backgroundColor: palette.background }}
          contentInsetAdjustmentBehavior="automatic"
          automaticallyAdjustKeyboardInsets
          keyboardShouldPersistTaps="handled"
          keyboardDismissMode="interactive"
          refreshControl={onRefresh ? <RefreshControl refreshing={!!refreshing} onRefresh={onRefresh} /> : undefined}
          contentContainerStyle={{ paddingBottom: 32 }}>
          {children}
        </ScrollView>
      ) : (
        <View style={{ flex: 1, backgroundColor: palette.background }}>{children}</View>
      )}
    </>
  );
}

function AndroidScreen({ title, root, modal, actions = [], search, scroll = true, onRefresh, refreshing, children }: ScreenProps) {
  const palette = usePalette();
  const close = useClose();
  const [query, setQuery] = useState('');
  return (
    <View style={{ flex: 1, backgroundColor: palette.background }}>
      <Appbar.Header mode={root ? 'medium' : 'small'} style={{ backgroundColor: palette.background }}>
        {modal ? (
          <Appbar.Action icon="close" accessibilityLabel={tr('btn.cancel')} onPress={close} />
        ) : root ? null : (
          <Appbar.BackAction onPress={close} />
        )}
        <Appbar.Content title={title} />
        {actions.map((a) => (
          <AndroidAction key={a.label} action={a} />
        ))}
      </Appbar.Header>
      {search ? (
        <Searchbar
          value={query}
          placeholder={search.placeholder}
          onChangeText={(text) => {
            setQuery(text);
            search.onChange(text);
          }}
          style={{ marginHorizontal: 16, marginBottom: 8 }}
          elevation={0}
        />
      ) : null}
      {scroll ? (
        <ScrollView
          style={{ flex: 1 }}
          keyboardShouldPersistTaps="handled"
          refreshControl={
            onRefresh ? (
              <RefreshControl refreshing={!!refreshing} onRefresh={onRefresh} colors={[palette.accent]} />
            ) : undefined
          }
          contentContainerStyle={{ paddingBottom: 32 }}>
          {children}
        </ScrollView>
      ) : (
        children
      )}
    </View>
  );
}

function AndroidAction({ action }: { action: Action }) {
  const palette = usePalette();
  const [open, setOpen] = useState(false);
  if (action.primary) {
    return (
      <PaperButton mode="contained" disabled={action.disabled} onPress={action.onPress} style={{ marginRight: 12 }}>
        {action.text ?? action.label}
      </PaperButton>
    );
  }
  if (!action.menu) {
    return (
      <Appbar.Action
        icon={action.icon}
        accessibilityLabel={action.label}
        disabled={action.disabled}
        onPress={action.onPress}
      />
    );
  }
  return (
    <Menu
      visible={open}
      onDismiss={() => setOpen(false)}
      anchorPosition="bottom"
      anchor={<Appbar.Action icon={action.icon} accessibilityLabel={action.label} onPress={() => setOpen(true)} />}>
      {action.menu.map((m) => (
        <Menu.Item
          key={m.label}
          title={m.label}
          leadingIcon={m.icon}
          trailingIcon={m.checked ? 'check' : undefined}
          titleStyle={m.destructive ? { color: palette.bad } : undefined}
          onPress={() => {
            setOpen(false);
            m.onPress();
          }}
        />
      ))}
    </Menu>
  );
}

// ----------------------------------------------------------------- sections

const IOS_RADIUS = 26;
const ANDROID_RADIUS = 24;

/** The page's side margin for cards and loose content. */
export const GUTTER = 16;

/**
 * A group of rows: an inset grouped list on iOS, a filled card under a header
 * on Android.
 */
export function Section({
  header,
  footer,
  children,
  style,
}: {
  header?: string;
  footer?: string;
  children: ReactNode;
  style?: StyleProp<ViewStyle>;
}) {
  const palette = usePalette();
  const rows = Children.toArray(children).filter(Boolean);
  // Dividers start at the rows' text: after the icons when the rows have them.
  const hasIcons = rows.some((r) => isValidElement<{ icon?: unknown }>(r) && r.props.icon != null);
  const inset = isIOS ? (hasIcons ? 60 : 16) : 16;
  return (
    <View style={[{ marginHorizontal: GUTTER, marginTop: isIOS ? 22 : 12 }, style]}>
      {header ? (
        <Text
          style={
            isIOS
              ? { fontSize: 13, color: palette.header, marginLeft: 16, marginBottom: 7 }
              : { fontSize: 14, fontWeight: '500', color: palette.header, marginLeft: 16, marginBottom: 8, marginTop: 8 }
          }>
          {header}
        </Text>
      ) : null}
      {rows.length > 0 ? (
        <View
          style={{
            backgroundColor: palette.card,
            borderRadius: isIOS ? IOS_RADIUS : ANDROID_RADIUS,
            borderCurve: 'continuous',
            overflow: 'hidden',
          }}>
          {rows.map((row, i) => (
            <View key={i}>
              {i > 0 && isIOS ? (
                <View style={{ height: StyleSheet.hairlineWidth, backgroundColor: palette.separator, marginLeft: inset }} />
              ) : null}
              {row}
            </View>
          ))}
        </View>
      ) : null}
      {footer ? (
        <Text style={{ fontSize: 13, lineHeight: 18, color: palette.secondary, marginHorizontal: 16, marginTop: 8 }}>
          {footer}
        </Text>
      ) : null}
    </View>
  );
}

/** A filled card for loose content (dashboard tiles). */
export function Card({ children, style }: { children: ReactNode; style?: StyleProp<ViewStyle> }) {
  const palette = usePalette();
  return (
    <View
      style={[
        {
          backgroundColor: palette.card,
          borderRadius: isIOS ? IOS_RADIUS : ANDROID_RADIUS,
          borderCurve: 'continuous',
          padding: 16,
        },
        style,
      ]}>
      {children}
    </View>
  );
}

/** A small heading above loose content, lined up with section headers. */
export function Heading({ children }: { children: string }) {
  const palette = usePalette();
  return (
    <Text
      style={
        isIOS
          ? { fontSize: 13, color: palette.header, marginLeft: GUTTER + 16, marginBottom: 7, marginTop: 22 }
          : { fontSize: 14, fontWeight: '500', color: palette.header, marginLeft: GUTTER + 16, marginBottom: 8, marginTop: 20 }
      }>
      {children}
    </Text>
  );
}

// --------------------------------------------------------------------- rows

export type RowIcon = { name: IconName; color?: string };

type RowProps = {
  title: string;
  subtitle?: string;
  /** How many lines the subtitle may take. */
  subtitleLines?: number;
  icon?: RowIcon;
  /** Current value, on the trailing side. */
  value?: string;
  trailing?: ReactNode;
  onPress?: () => void;
  onLongPress?: () => void;
  /** Shows a disclosure chevron on iOS (rows that open something). */
  chevron?: boolean;
  destructive?: boolean;
  disabled?: boolean;
  testID?: string;
};

/** The coloured rounded-square icon of iOS Settings rows; a plain icon on Android. */
function RowLeading({ icon }: { icon: RowIcon }) {
  const palette = usePalette();
  if (!isIOS) {
    return <Icon name={icon.name} size={24} color={icon.color ?? palette.secondary} style={{ marginRight: 16 }} />;
  }
  return (
    <View
      style={{
        width: 30,
        height: 30,
        borderRadius: 7,
        borderCurve: 'continuous',
        backgroundColor: icon.color ?? palette.accent,
        alignItems: 'center',
        justifyContent: 'center',
        marginRight: 14,
      }}>
      <Icon name={icon.name} size={18} color="#FFFFFF" />
    </View>
  );
}

export function Row({
  title,
  subtitle,
  subtitleLines = 3,
  icon,
  value,
  trailing,
  onPress,
  onLongPress,
  chevron,
  destructive,
  disabled,
  testID,
}: RowProps) {
  const palette = usePalette();
  const titleColor = destructive ? palette.bad : disabled ? palette.tertiary : palette.text;
  // Android shows a value under the title when there is no description.
  const below = subtitle ?? (isIOS ? undefined : value);
  const beside = isIOS || subtitle ? value : undefined;
  const content = (
    <View
      style={{
        flexDirection: 'row',
        alignItems: 'center',
        minHeight: isIOS ? 44 : 56,
        paddingHorizontal: 16,
        paddingVertical: isIOS ? 10 : 8,
      }}>
      {icon ? <RowLeading icon={icon} /> : null}
      <View style={{ flex: 1, justifyContent: 'center' }}>
        <Text style={{ fontSize: isIOS ? 17 : 16, color: titleColor }}>{title}</Text>
        {below ? (
          <Text
            numberOfLines={subtitleLines}
            style={{ fontSize: isIOS ? 13 : 14, lineHeight: isIOS ? 18 : 20, color: palette.secondary, marginTop: 2 }}>
            {below}
          </Text>
        ) : null}
      </View>
      {beside ? (
        <Text numberOfLines={1} style={{ fontSize: isIOS ? 17 : 14, color: palette.secondary, marginLeft: 12, maxWidth: '45%' }}>
          {beside}
        </Text>
      ) : null}
      {trailing ? <View style={{ marginLeft: 12 }}>{trailing}</View> : null}
      {isIOS && chevron && onPress ? (
        <Icon name="chevron" size={14} color={palette.tertiary} style={{ marginLeft: 8 }} />
      ) : null}
    </View>
  );
  if (!onPress && !onLongPress) return <View testID={testID}>{content}</View>;
  return (
    <Pressable
      testID={testID}
      onPress={onPress}
      onLongPress={onLongPress}
      disabled={disabled}
      android_ripple={{ color: palette.fill }}
      style={({ pressed }) => (isIOS && pressed ? { backgroundColor: palette.fill } : undefined)}>
      {content}
    </Pressable>
  );
}

/** The platform's switch: UISwitch on iOS, the Material 3 one on Android. */
export function Toggle({ value, onChange, disabled }: { value: boolean; onChange?: (v: boolean) => void; disabled?: boolean }) {
  return isIOS ? (
    <Switch value={value} onValueChange={onChange} disabled={disabled} />
  ) : (
    <PaperSwitch value={value} onValueChange={onChange} disabled={disabled} />
  );
}

export function SwitchRow({
  title,
  subtitle,
  icon,
  value,
  onChange,
  testID,
}: {
  title: string;
  subtitle?: string;
  icon?: RowIcon;
  value: boolean;
  onChange: (v: boolean) => void;
  testID?: string;
}) {
  return (
    <Row
      title={title}
      subtitle={subtitle}
      icon={icon}
      testID={testID}
      trailing={<Toggle value={value} onChange={onChange} />}
      // Android: the whole row toggles, as in system settings.
      onPress={isIOS ? undefined : () => onChange(!value)}
    />
  );
}

/** A row picking one of `options`: an action sheet on iOS, a radio dialog on Android. */
export function ChoiceRow<T>({
  title,
  message,
  icon,
  value,
  options,
  onChange,
}: {
  title: string;
  /** Explains the choice, in the picker. */
  message?: string;
  icon?: RowIcon;
  value: T;
  options: Option<T>[];
  onChange: (v: T) => void;
}) {
  const current = options.find((o) => o.value === value)?.label ?? String(value);
  return (
    <Row
      title={title}
      icon={icon}
      value={current}
      chevron
      onPress={async () => {
        const picked = await askChoice({ title, message, options, value });
        if (picked !== undefined && picked !== value) onChange(picked);
      }}
    />
  );
}

/** A row with a text value, edited in a prompt. */
export function TextRow({
  title,
  description,
  icon,
  value,
  onChange,
  placeholder,
  keyboardType,
  validate,
  display,
}: {
  title: string;
  description?: string;
  icon?: RowIcon;
  value: string;
  onChange: (v: string) => void;
  placeholder?: string;
  keyboardType?: KeyboardTypeOptions;
  validate?: (text: string) => string | null;
  /** How the value is shown in the row (defaults to the value). */
  display?: string;
}) {
  const shown = display ?? (value === '' ? (placeholder ?? '') : value);
  return (
    <Row
      title={title}
      subtitle={description}
      icon={icon}
      value={shown}
      chevron
      onPress={async () => {
        const text = await askText({ title, message: description, initial: value, placeholder, keyboardType, validate });
        if (text !== null && text !== value) onChange(text);
      }}
    />
  );
}

// ----------------------------------------------------------------- controls

/** UISegmentedControl on iOS, Material 3 segmented buttons on Android. */
export function Segmented({
  labels,
  index,
  onChange,
}: {
  labels: string[];
  index: number;
  onChange: (index: number) => void;
}) {
  if (isIOS) {
    return (
      <SegmentedControl
        values={labels}
        selectedIndex={index}
        onChange={(e) => onChange(e.nativeEvent.selectedSegmentIndex)}
      />
    );
  }
  return (
    <SegmentedButtons
      value={String(index)}
      onValueChange={(v) => onChange(Number(v))}
      buttons={labels.map((label, i) => ({ value: String(i), label, showSelectedCheck: true }))}
    />
  );
}

/** A filled (or tinted) button: a capsule on iOS, a Material 3 button on Android. */
export function Button({
  label,
  onPress,
  tinted,
  disabled,
  testID,
}: {
  label: string;
  onPress: () => void;
  /** Quieter: a tinted fill instead of the solid accent. */
  tinted?: boolean;
  disabled?: boolean;
  testID?: string;
}) {
  const palette = usePalette();
  if (!isIOS) {
    return (
      <PaperButton testID={testID} mode={tinted ? 'contained-tonal' : 'contained'} disabled={disabled} onPress={onPress}>
        {label}
      </PaperButton>
    );
  }
  return (
    <Pressable
      testID={testID}
      disabled={disabled}
      onPress={onPress}
      style={({ pressed }) => ({
        backgroundColor: tinted ? palette.fill : palette.accent,
        opacity: disabled ? 0.4 : pressed ? 0.7 : 1,
        borderRadius: 25,
        minHeight: 50,
        paddingHorizontal: 22,
        alignItems: 'center',
        justifyContent: 'center',
      })}>
      <Text style={{ fontSize: 17, fontWeight: '600', color: tinted ? palette.accent : palette.onAccent }}>{label}</Text>
    </Pressable>
  );
}

/** A small pill that opens a picker (the Auto group's mode and region). */
export function Chip({ icon, label, onPress }: { icon: IconName; label: string; onPress: () => void }) {
  const palette = usePalette();
  return (
    <Pressable
      onPress={onPress}
      android_ripple={{ color: palette.fill, borderless: false }}
      style={({ pressed }) => ({
        flexDirection: 'row',
        alignItems: 'center',
        gap: 6,
        paddingHorizontal: 12,
        height: 34,
        borderRadius: isIOS ? 17 : 8,
        backgroundColor: isIOS ? palette.fill : 'transparent',
        borderWidth: isIOS ? 0 : 1,
        borderColor: palette.separator,
        opacity: isIOS && pressed ? 0.6 : 1,
        overflow: 'hidden',
      })}>
      <Icon name={icon} size={16} color={palette.accent} />
      <Text style={{ fontSize: 14, fontWeight: '500', color: palette.text }}>{label}</Text>
      <Icon name="expand" size={12} color={palette.secondary} />
    </Pressable>
  );
}

/** Centered message for empty or offline pages. */
export function EmptyState({
  icon,
  title,
  message,
  action,
}: {
  icon: IconName;
  title: string;
  message?: string;
  action?: ReactNode;
}) {
  const palette = usePalette();
  return (
    <View style={{ alignItems: 'center', paddingHorizontal: 40, paddingVertical: 64 }}>
      <Icon name={icon} size={52} color={palette.secondary} />
      <Text style={{ fontSize: 20, fontWeight: '600', color: palette.text, marginTop: 16, textAlign: 'center' }}>
        {title}
      </Text>
      {message ? (
        <Text style={{ fontSize: 15, lineHeight: 21, color: palette.secondary, marginTop: 8, textAlign: 'center' }}>
          {message}
        </Text>
      ) : null}
      {action ? <View style={{ marginTop: 24 }}>{action}</View> : null}
    </View>
  );
}

export function Spinner({ size = 16 }: { size?: number }) {
  const palette = usePalette();
  return <ActivityIndicator size={isIOS ? 'small' : size} color={isIOS ? undefined : palette.accent} />;
}

// -------------------------------------------------------------------- forms

/** A labelled text field for a form [Section]. */
export function Field({
  label,
  value,
  onChange,
  placeholder,
  keyboardType,
  multiline,
  error,
  autoFocus,
  monospace,
  testID,
}: {
  label: string;
  value: string;
  onChange: (text: string) => void;
  placeholder?: string;
  keyboardType?: KeyboardTypeOptions;
  multiline?: boolean;
  error?: string | null;
  autoFocus?: boolean;
  monospace?: boolean;
  testID?: string;
}) {
  const palette = usePalette();
  const font = monospace ? ({ fontFamily: isIOS ? 'Menlo' : 'monospace', fontSize: 13 } as const) : null;
  if (!isIOS) {
    return (
      <View style={{ paddingHorizontal: 16, paddingTop: 12, paddingBottom: 4 }}>
        <PaperTextInput
          testID={testID}
          mode="outlined"
          label={label}
          value={value}
          onChangeText={onChange}
          placeholder={placeholder}
          keyboardType={keyboardType}
          multiline={multiline}
          numberOfLines={multiline ? 5 : 1}
          autoCorrect={false}
          autoCapitalize="none"
          autoFocus={autoFocus}
          error={!!error}
          style={[multiline ? { minHeight: 120 } : null, font]}
        />
        {error ? <Text style={{ fontSize: 12, color: palette.bad, marginTop: 4, marginLeft: 16 }}>{error}</Text> : null}
      </View>
    );
  }
  const input = (
    <TextInput
      testID={testID}
      value={value}
      onChangeText={onChange}
      placeholder={placeholder}
      placeholderTextColor={palette.tertiary}
      keyboardType={keyboardType}
      multiline={multiline}
      autoCorrect={false}
      autoCapitalize="none"
      autoFocus={autoFocus}
      clearButtonMode={multiline ? 'never' : 'while-editing'}
      style={[
        { flex: 1, fontSize: 17, color: palette.text, padding: 0 },
        multiline ? { minHeight: 110, textAlignVertical: 'top' } : null,
        font,
      ]}
    />
  );
  return (
    <View style={{ paddingHorizontal: 16, paddingVertical: 11 }}>
      {multiline ? (
        <>
          <Text style={{ fontSize: 13, color: palette.secondary, marginBottom: 6 }}>{label}</Text>
          {input}
        </>
      ) : (
        <View style={{ flexDirection: 'row', alignItems: 'center' }}>
          <Text style={{ fontSize: 17, color: palette.text, width: 112, marginRight: 8 }} numberOfLines={2}>
            {label}
          </Text>
          {input}
        </View>
      )}
      {error ? <Text style={{ fontSize: 13, color: palette.bad, marginTop: 6 }}>{error}</Text> : null}
    </View>
  );
}
