// Questions for the user: pick one, enter text, confirm.
// iOS uses the system's own action sheets and alerts; Android shows Material 3
// dialogs through [DialogHost], mounted once at the root.

import { useState } from 'react';
import { ActionSheetIOS, Alert, type KeyboardTypeOptions, ScrollView, View } from 'react-native';
import { Button, Dialog, Portal, RadioButton, Text, TextInput } from 'react-native-paper';
import { create } from 'zustand';

import { tr } from '../i18n';
import { isIOS, usePalette } from './theme';

export type Option<T> = { value: T; label: string; destructive?: boolean };

type ChoiceRequest = {
  kind: 'choice';
  title: string;
  message?: string;
  options: Option<unknown>[];
  value?: unknown;
  /** Rows that act at once (a menu), without a selected one. */
  menu?: boolean;
  done: (value: unknown) => void;
};

type TextRequest = {
  kind: 'text';
  title: string;
  message?: string;
  initial: string;
  placeholder?: string;
  keyboardType?: KeyboardTypeOptions;
  multiline?: boolean;
  confirmLabel: string;
  validate?: (text: string) => string | null;
  done: (value: string | null) => void;
};

type ConfirmRequest = {
  kind: 'confirm';
  title: string;
  message?: string;
  confirmLabel: string;
  destructive?: boolean;
  done: (value: boolean) => void;
};

type Request = ChoiceRequest | TextRequest | ConfirmRequest;

const useDialog = create<{ request: Request | null }>(() => ({ request: null }));

/** Picks one of `options`. Resolves to undefined when dismissed. */
export function askChoice<T>(q: {
  title: string;
  message?: string;
  options: Option<T>[];
  value?: T;
  menu?: boolean;
}): Promise<T | undefined> {
  return new Promise((resolve) => {
    if (isIOS) {
      const labels = q.options.map((o) => (o.value === q.value && !q.menu ? `${o.label}  ✓` : o.label));
      const destructive = q.options.map((o, i) => (o.destructive ? i : -1)).filter((i) => i >= 0);
      ActionSheetIOS.showActionSheetWithOptions(
        {
          title: q.title,
          message: q.message,
          options: [...labels, tr('btn.cancel')],
          cancelButtonIndex: labels.length,
          destructiveButtonIndex: destructive,
        },
        (i) => resolve(i < q.options.length ? q.options[i].value : undefined),
      );
      return;
    }
    useDialog.setState({
      request: { kind: 'choice', ...q, options: q.options, done: (v) => resolve(v as T | undefined) },
    });
  });
}

/** Asks for a line (or block) of text. Resolves to null when cancelled. */
export function askText(q: {
  title: string;
  message?: string;
  initial?: string;
  placeholder?: string;
  keyboardType?: KeyboardTypeOptions;
  multiline?: boolean;
  confirmLabel?: string;
  /** An error text for an unacceptable value, or null. */
  validate?: (text: string) => string | null;
}): Promise<string | null> {
  const confirmLabel = q.confirmLabel ?? tr('btn.save');
  return new Promise((resolve) => {
    if (isIOS && !q.multiline) {
      const prompt = (message: string | undefined, initial: string) =>
        Alert.prompt(
          q.title,
          message,
          [
            { text: tr('btn.cancel'), style: 'cancel', onPress: () => resolve(null) },
            {
              text: confirmLabel,
              isPreferred: true,
              onPress: (text?: string) => {
                const value = (text ?? '').trim();
                const error = q.validate?.(value);
                // The system alert has no room for an error: ask again with it.
                if (error) prompt(error, value);
                else resolve(value);
              },
            },
          ],
          'plain-text',
          initial,
          q.keyboardType,
        );
      prompt(q.message, q.initial ?? '');
      return;
    }
    useDialog.setState({
      request: { kind: 'text', ...q, initial: q.initial ?? '', confirmLabel, done: resolve },
    });
  });
}

/** A yes/no question. */
export function askConfirm(q: {
  title: string;
  message?: string;
  confirmLabel: string;
  destructive?: boolean;
}): Promise<boolean> {
  return new Promise((resolve) => {
    if (isIOS) {
      Alert.alert(q.title, q.message, [
        { text: tr('btn.cancel'), style: 'cancel', onPress: () => resolve(false) },
        { text: q.confirmLabel, style: q.destructive ? 'destructive' : 'default', onPress: () => resolve(true) },
      ]);
      return;
    }
    useDialog.setState({ request: { kind: 'confirm', ...q, done: resolve } });
  });
}

/** Renders the pending question on Android (and multi-line text on iOS). */
export function DialogHost() {
  const request = useDialog((s) => s.request);
  const close = () => useDialog.setState({ request: null });
  return (
    <Portal>
      {request?.kind === 'choice' && <ChoiceDialog request={request} close={close} />}
      {request?.kind === 'text' && <TextDialog request={request} close={close} />}
      {request?.kind === 'confirm' && <ConfirmDialog request={request} close={close} />}
    </Portal>
  );
}

function ChoiceDialog({ request, close }: { request: ChoiceRequest; close: () => void }) {
  const palette = usePalette();
  const finish = (value: unknown) => {
    close();
    request.done(value);
  };
  return (
    <Dialog visible onDismiss={() => finish(undefined)} style={{ maxHeight: '80%' }}>
      <Dialog.Title>{request.title}</Dialog.Title>
      {request.message ? (
        <Dialog.Content>
          <Text variant="bodyMedium">{request.message}</Text>
        </Dialog.Content>
      ) : null}
      <Dialog.ScrollArea style={{ paddingHorizontal: 0 }}>
        <ScrollView>
          {request.options.map((o, i) =>
            request.menu ? (
              <Button
                key={i}
                onPress={() => finish(o.value)}
                textColor={o.destructive ? palette.bad : palette.text}
                contentStyle={{ justifyContent: 'flex-start', paddingHorizontal: 16, paddingVertical: 6 }}>
                {o.label}
              </Button>
            ) : (
              <RadioButton.Item
                key={i}
                label={o.label}
                value={String(i)}
                position="leading"
                labelStyle={{ textAlign: 'left' }}
                status={o.value === request.value ? 'checked' : 'unchecked'}
                onPress={() => finish(o.value)}
              />
            ),
          )}
        </ScrollView>
      </Dialog.ScrollArea>
      <Dialog.Actions>
        <Button onPress={() => finish(undefined)}>{tr('btn.cancel')}</Button>
      </Dialog.Actions>
    </Dialog>
  );
}

function TextDialog({ request, close }: { request: TextRequest; close: () => void }) {
  const [text, setText] = useState(request.initial);
  const [error, setError] = useState<string | null>(null);
  const palette = usePalette();
  const finish = (value: string | null) => {
    close();
    request.done(value);
  };
  const submit = () => {
    const value = request.multiline ? text : text.trim();
    const problem = request.validate?.(value) ?? null;
    if (problem) setError(problem);
    else finish(value);
  };
  return (
    <Dialog visible onDismiss={() => finish(null)}>
      <Dialog.Title>{request.title}</Dialog.Title>
      <Dialog.Content>
        {request.message ? (
          <Text variant="bodyMedium" style={{ marginBottom: 16 }}>
            {request.message}
          </Text>
        ) : null}
        <TextInput
          mode="outlined"
          value={text}
          onChangeText={(v) => {
            setText(v);
            setError(null);
          }}
          placeholder={request.placeholder}
          keyboardType={request.multiline ? 'default' : request.keyboardType}
          multiline={request.multiline}
          numberOfLines={request.multiline ? 6 : 1}
          autoFocus
          autoCorrect={false}
          autoCapitalize="none"
          error={error != null}
          onSubmitEditing={request.multiline ? undefined : submit}
          style={request.multiline ? { minHeight: 140 } : undefined}
        />
        {error ? (
          <View style={{ paddingTop: 6, paddingHorizontal: 4 }}>
            <Text variant="bodySmall" style={{ color: palette.bad }}>
              {error}
            </Text>
          </View>
        ) : null}
      </Dialog.Content>
      <Dialog.Actions>
        <Button onPress={() => finish(null)}>{tr('btn.cancel')}</Button>
        <Button mode="contained" onPress={submit} style={{ paddingHorizontal: 8 }}>
          {request.confirmLabel}
        </Button>
      </Dialog.Actions>
    </Dialog>
  );
}

function ConfirmDialog({ request, close }: { request: ConfirmRequest; close: () => void }) {
  const palette = usePalette();
  const finish = (value: boolean) => {
    close();
    request.done(value);
  };
  return (
    <Dialog visible onDismiss={() => finish(false)}>
      <Dialog.Title>{request.title}</Dialog.Title>
      {request.message ? (
        <Dialog.Content>
          <Text variant="bodyMedium">{request.message}</Text>
        </Dialog.Content>
      ) : null}
      <Dialog.Actions>
        <Button onPress={() => finish(false)}>{tr('btn.cancel')}</Button>
        <Button onPress={() => finish(true)} textColor={request.destructive ? palette.bad : undefined}>
          {request.confirmLabel}
        </Button>
      </Dialog.Actions>
    </Dialog>
  );
}
