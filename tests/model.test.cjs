const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const root = path.join(__dirname, '..');
const model = vm.createContext({});
vm.runInContext(fs.readFileSync(path.join(root, 'Model.js'), 'utf8'), model);
const defaults = JSON.parse(fs.readFileSync(path.join(root, 'personality.json'), 'utf8'));
const plain = value => JSON.parse(JSON.stringify(value));
const minute = 60000;

test('all 101 messages personalize safely, with a natural no-name fallback', () => {
  const values = [...defaults.hydrationMessages, ...Object.values(defaults.periods).flatMap(x => x.messages)];
  assert.equal(values.length, 101);
  for (const value of values) {
    assert.ok(value.includes('{name}'), value);
    assert.ok(model.formatMessage(value, 'Javi').includes('Javi'));
    const anonymous = model.formatMessage(value, '');
    assert.ok(!anonymous.includes('{name}'));
    assert.ok(!/^[, .]|,\s*[,.]|\s[.]/.test(anonymous), anonymous);
  }
  assert.equal(model.formatMessage('{name}, recuerda tomar agüita', ''), 'Recuerda tomar agüita');
  assert.equal(model.formatMessage('Hola, {name}', '$&<test>'), 'Hola, $&<test>');
});

test('each group exhausts its messages before repeating, including across persisted reloads', () => {
  for (const key of [...Object.keys(defaults.periods), 'hydration']) {
    const values = model.messages(defaults, key);
    let state = model.restore(null);
    const seen = new Set();
    for (let i = 0; i < values.length; i++) {
      const message = model.draw(state, key, values, () => 0);
      assert.ok(!seen.has(message));
      seen.add(message);
      state = model.restore(JSON.parse(JSON.stringify(state)));
    }
    const last = state.groups[key].current;
    assert.notEqual(model.draw(state, key, values, () => 0), last);
  }
});

test('water at 30 visible minutes, normal phrases at 10; hydration does not consume normal pool', () => {
  let state = model.advance(model.restore(null), 0, 'morning', defaults, () => 0);
  const first = state.current;
  state = model.advance(state, 9 * minute, 'morning', defaults, () => 0);
  assert.equal(state.current, first);
  state = model.advance(state, minute, 'morning', defaults, () => 0);
  assert.notEqual(state.current, first);
  state = model.advance(state, 10 * minute, 'morning', defaults, () => 0);
  const normalSeen = plain(state.groups.morning.seen);
  state = model.advance(state, 10 * minute, 'morning', defaults, () => 0);
  assert.equal(state.activeGroup, 'hydration');
  assert.deepEqual(plain(state.groups.morning.seen), normalSeen);
  state = model.advance(state, 10 * minute, 'morning', defaults, () => 0);
  assert.equal(state.activeGroup, 'morning');
  assert.equal(state.groups.morning.seen.length, normalSeen.length + 1);
  state = model.advance(state, 20 * minute, 'morning', defaults, () => 0);
  assert.equal(state.activeGroup, 'hydration');
  assert.equal(state.groups.hydration.seen.length, 2);
});

test('reload and zero hidden-time delta preserve current phrase and timers', () => {
  let state = model.advance(model.restore(null), 0, 'night', defaults, () => 0);
  state = model.advance(state, 7 * minute, 'night', defaults, () => 0);
  const saved = JSON.stringify(state);
  state = model.advance(model.restore(JSON.parse(saved)), 0, 'night', defaults, () => 0);
  assert.equal(JSON.stringify(state), saved);
  state = model.advance(state, 3 * minute, 'night', defaults, () => 0);
  assert.notEqual(state.current, JSON.parse(saved).current);
});

test('period changes resume the last phrase in that group without consuming another', () => {
  let state = model.advance(model.restore(null), 0, 'morning', defaults, () => 0);
  const morning = state.current;
  state = model.advance(state, 0, 'afternoon', defaults, () => 0);
  assert.notEqual(state.current, morning);
  state = model.advance(state, 0, 'morning', defaults, () => 0);
  assert.equal(state.current, morning);
  assert.equal(state.groups.morning.seen.length, 1);
});

test('updated phrase lists keep progress, drop removed entries and include new ones', () => {
  const state = model.restore(null);
  model.draw(state, 'night', ['a', 'b'], () => 0);
  assert.equal(model.draw(state, 'night', ['a', 'c'], () => 0), 'c');
  assert.equal(model.draw(state, 'night', ['c'], () => 0), 'c');
  assert.equal(model.draw(state, 'empty', [], () => 0), '');
});

test('overrides preserve defaults, zero margins, Unicode names and safe timing bounds', () => {
  const config = model.settings(defaults, { marginRight: 0, creature: 'ฅ(•ㅅ•)ฅ', periods: { night: { messages: ['Hi, {name}'] } }, hydrationEveryMinutes: -1 });
  assert.equal(config.marginRight, 0);
  assert.equal(config.hydrationEveryMinutes, 30);
  assert.equal(config.periods.morning.messages.length, 22);
  assert.equal(config.periods.night.messages.length, 1);
  assert.equal(model.cleanName('  Javí\n '), 'Javí');
  assert.equal(model.periodAt(5), 'morning');
  assert.equal(model.periodAt(12), 'afternoon');
  assert.equal(model.periodAt(19), 'evening');
  assert.equal(model.periodAt(23), 'night');
});
