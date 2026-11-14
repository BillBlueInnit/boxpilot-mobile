import { useEffect, useState } from 'react';

import { tr } from '../i18n';
import { useStore } from './store';

/**
 * The translator, re-rendering the component when the language changes.
 * Components call this instead of importing `tr`, which reads the language
 * without subscribing to it.
 */
export function useT() {
  useStore((s) => s.language);
  return tr;
}

/**
 * The time in ms, refreshed every `seconds`: re-renders "5m ago" texts and
 * uptimes without reading the clock during render.
 */
export function useTick(seconds: number, active = true): number {
  const [now, setNow] = useState(() => Date.now());
  useEffect(() => {
    if (!active) return;
    const timer = setInterval(() => setNow(Date.now()), seconds * 1000);
    return () => clearInterval(timer);
  }, [seconds, active]);
  return now;
}
