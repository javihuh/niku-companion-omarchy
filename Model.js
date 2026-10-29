// Pure logic shared by Quickshell and the Node test suite.
function object(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function positive(value, fallback) {
  var n = Number(value);
  return isFinite(n) && n > 0 ? n : fallback;
}

function cleanName(value) {
  return String(value || "").replace(/[\x00-\x1f\x7f]/g, "").trim().slice(0, 60);
}

function formatMessage(template, name) {
  name = cleanName(name);
  var text = String(template || "");
  if (name) return text.split("{name}").join(name);
  // Templates place the optional name at sentence boundaries or between commas.
  text = text.replace(/, \{name\},/g, ",")
    .replace(/\{name\},\s*/g, "")
    .replace(/, \{name\}/g, "")
    .replace(/\{name\}/g, "").trim();
  return text.charAt(0).toUpperCase() + text.slice(1);
}

function periodAt(hour) {
  if (hour >= 5 && hour < 12) return "morning";
  if (hour >= 12 && hour < 19) return "afternoon";
  if (hour >= 19 && hour < 23) return "evening";
  return "night";
}

function settings(defaults, overrides) {
  var result = Object.assign({}, defaults, overrides);
  result.periods = Object.assign({}, defaults.periods || {}, overrides.periods || {});
  result.changeMinutes = positive(result.changeMinutes, 10);
  result.hydrationEveryMinutes = Math.max(result.changeMinutes,
    positive(result.hydrationEveryMinutes, 30));
  result.workspace = Math.max(1, Math.floor(positive(result.workspace, 1)));
  return result;
}

function messages(config, key) {
  var values = key === "hydration" ? config.hydrationMessages
    : (config.periods && config.periods[key] ? config.periods[key].messages : []);
  if (!Array.isArray(values)) return [];
  return values.filter(function(value, index) {
    return typeof value === "string" && value.trim() && values.indexOf(value) === index;
  });
}

function restore(value) {
  var state = object(value) && value.version === 1 ? value : {};
  return {
    version: 1,
    groups: object(state.groups) ? state.groups : {},
    activeGroup: typeof state.activeGroup === "string" ? state.activeGroup : "",
    current: typeof state.current === "string" ? state.current : "",
    elapsedMs: Math.max(0, Number(state.elapsedMs) || 0),
    hydrationElapsedMs: Math.max(0, Number(state.hydrationElapsedMs) || 0)
  };
}

function draw(state, key, values, random) {
  if (!values.length) return "";
  var group = object(state.groups[key]) ? state.groups[key] : {};
  var seen = Array.isArray(group.seen) ? group.seen.filter(function(x) {
    return values.indexOf(x) !== -1;
  }) : [];
  var remaining = values.filter(function(x) { return seen.indexOf(x) === -1; });
  if (!remaining.length) {
    seen = [];
    remaining = values.filter(function(x) { return values.length === 1 || x !== group.current; });
  }
  var chosen = remaining[Math.min(remaining.length - 1, Math.floor(random() * remaining.length))];
  seen.push(chosen);
  state.groups[key] = { seen: seen, current: chosen };
  return chosen;
}

// Called only while the companion's workspace is active. No wall-clock slots:
// hidden time cannot consume phrases or trigger a burst of reminders on return.
function advance(previous, deltaMs, period, config, random) {
  random = random || Math.random;
  var state = restore(JSON.parse(JSON.stringify(previous)));
  var changeMs = positive(config.changeMinutes, 10) * 60000;
  var hydrationMs = Math.max(changeMs, positive(config.hydrationEveryMinutes, 30) * 60000);
  var elapsed = Math.max(0, Number(deltaMs) || 0);
  state.elapsedMs += elapsed;
  state.hydrationElapsedMs += elapsed;
  var water = messages(config, "hydration");
  if (water.length && state.hydrationElapsedMs >= hydrationMs) {
    state.activeGroup = "hydration";
    state.current = draw(state, "hydration", water, random);
    state.hydrationElapsedMs = 0;
    state.elapsedMs = 0;
    return state;
  }
  var activeValues = messages(config, state.activeGroup);
  var invalid = !state.current || activeValues.indexOf(state.current) === -1;
  var switchPeriod = state.activeGroup !== "hydration" && state.activeGroup !== period;
  if (invalid || switchPeriod || state.elapsedMs >= changeMs) {
    var values = messages(config, period);
    var saved = state.groups[period];
    // Returning to a period resumes its last phrase, rather than skipping it.
    state.current = switchPeriod && saved && values.indexOf(saved.current) !== -1
      ? saved.current : draw(state, period, values, random);
    state.activeGroup = period;
    state.elapsedMs = 0;
  }
  return state;
}
