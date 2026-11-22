import assert from 'node:assert/strict';
import test from 'node:test';

import { setLanguage } from '../i18n';
import type { Group, RuleProvider } from './engine';
import {
  extraTargetGroups,
  kindLabel,
  kindPlaceholder,
  profileMeta,
  providerSummary,
  providerTargetLabel,
  providerTitle,
  targetLabel,
} from './rules-ui';

function makeProvider(overrides: Partial<RuleProvider> = {}): RuleProvider {
  return {
    id: 'p1',
    name: 'Example Set',
    source: 'https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/geosite-ai.srs',
    format: 'auto',
    target: 'proxy',
    enabled: true,
    interval_hours: 24,
    rule_count: 10,
    own_group: false,
    region: '',
    ...overrides,
  };
}

test('rules-ui formats curated presets and hides raw GitHub URLs', () => {
  setLanguage('en');
  const preset = makeProvider({ preset: 'ai', name: 'AI Services', own_group: true });
  assert.equal(providerTitle(preset), 'AI Services');
  assert.match(providerSummary(preset), /OpenAI/);
  assert.equal(providerTargetLabel(preset), 'Own group');

  const external = makeProvider();
  assert.equal(providerSummary(external), 'raw.githubusercontent.com / geosite-ai.srs');
  assert.equal(providerTargetLabel(external), 'Proxy');

  const rejected = makeProvider({ target: 'reject', own_group: true });
  assert.equal(providerTargetLabel(rejected), 'Reject');
});

test('rules-ui formats targets, kinds, placeholders and profiles across locales', () => {
  setLanguage('zh-CN');
  assert.equal(targetLabel('proxy'), '代理');
  assert.equal(targetLabel('direct'), '直连');
  assert.equal(targetLabel('reject'), '拦截');
  assert.equal(targetLabel('AI Services'), 'AI 服务');
  assert.equal(kindLabel('DOMAIN-SUFFIX'), '网站（含子域名）');
  assert.match(kindPlaceholder('IP-CIDR'), /CIDR|IP/);
  assert.equal(profileMeta('daily').title, '日常推荐');
  setLanguage('en');
});

test('extraTargetGroups merges running groups and offline own-group rule-sets without built-ins', () => {
  const groups: Group[] = [
    { name: 'Proxy', kind: 'Selector', now: 'Auto', selectable: true, local_nodes: false, rule_group: null, members: [] },
    { name: 'Auto', kind: 'URLTest', now: 'n1', selectable: false, local_nodes: false, rule_group: null, members: [] },
    { name: 'YouTube', kind: 'Selector', now: 'n1', selectable: true, local_nodes: false, rule_group: { id: 'yt', pick: null, region: '' }, members: [] },
  ];
  const providers: RuleProvider[] = [
    makeProvider({ id: 'ai', name: 'AI Services', own_group: true, enabled: true }),
    makeProvider({ id: 'yt', name: 'YouTube', own_group: true, enabled: true }),
    makeProvider({ id: 'off', name: 'Disabled', own_group: true, enabled: false }),
    makeProvider({ id: 'rej', name: 'Ads', target: 'reject', own_group: true, enabled: true }),
  ];
  const customGroups = [
    { id: 'cg1', name: 'Work', target: 'proxy', enabled: true, own_group: true, pick: null, region: 'US' },
    { id: 'cg2', name: 'DirectOnly', target: 'direct', enabled: true, own_group: false, pick: null, region: '' },
  ];
  assert.deepEqual(extraTargetGroups(groups, providers, customGroups), ['YouTube', 'Work', 'AI Services']);
});
