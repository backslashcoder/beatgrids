/*
 * BeatGrid audio engine.
 *
 * Owns all Tone.js scheduling and sound generation. Flutter only sends
 * high-level commands (see docs/AUDIO_ENGINE.md) and receives low-frequency
 * status events (one per step change, plus state changes).
 *
 * Drum sounds are synthesized in real time, so the project ships no sample
 * files and has no third-party sample licensing to track.
 */
(function () {
  'use strict';

  var STEPS = 16;
  var MIN_BPM = 60;
  var MAX_BPM = 180;
  var TRACK_IDS = ['kick', 'snare', 'closed_hat', 'open_hat', 'clap'];

  var engine = null; // created by init(), cleared by dispose()
  var initPromise = null;
  var statusListener = null;
  var timers = []; // pending UI-timing timeouts, cleared on stop/dispose

  // Runs fn when audio time `time` is reached. Used only for UI status, never
  // for sound. Avoids requestAnimationFrame so the playhead keeps reporting
  // even when the page is not being painted.
  function atAudioTime(time, fn) {
    var id = setTimeout(function () {
      var i = timers.indexOf(id);
      if (i >= 0) timers.splice(i, 1);
      fn();
    }, Math.max(0, (time - Tone.now()) * 1000));
    timers.push(id);
  }

  function clearTimers() {
    timers.forEach(clearTimeout);
    timers = [];
  }

  function clamp(v, lo, hi) {
    return Math.min(hi, Math.max(lo, v));
  }

  function emptyPattern() {
    var tracks = {};
    TRACK_IDS.forEach(function (id) {
      tracks[id] = new Array(STEPS).fill(false);
    });
    return tracks;
  }

  function emit() {
    if (!statusListener || !engine) return;
    try {
      statusListener(engine.state, engine.step);
    } catch (e) {
      console.error('[BeatGridAudio] status listener failed', e);
    }
  }

  function setState(state) {
    if (!engine || engine.state === state) return;
    engine.state = state;
    emit();
  }

  function requireEngine() {
    if (!engine) throw new Error('Audio engine is not initialized.');
    return engine;
  }

  function buildVoices(master) {
    var voices = {};
    var gains = {};
    TRACK_IDS.forEach(function (id) {
      gains[id] = new Tone.Gain(0.8).connect(master);
    });

    var kick = new Tone.MembraneSynth({
      pitchDecay: 0.05,
      octaves: 8,
      oscillator: { type: 'sine' },
      envelope: { attack: 0.001, decay: 0.32, sustain: 0, release: 0.1 },
    }).connect(gains.kick);

    var snareNoise = new Tone.NoiseSynth({
      noise: { type: 'white' },
      envelope: { attack: 0.001, decay: 0.17, sustain: 0, release: 0.05 },
    }).connect(new Tone.Filter(1800, 'highpass').connect(gains.snare));
    var snareBody = new Tone.Synth({
      oscillator: { type: 'triangle' },
      envelope: { attack: 0.001, decay: 0.1, sustain: 0, release: 0.05 },
    }).connect(gains.snare);

    var hatFilter = new Tone.Filter(7500, 'highpass').connect(gains.closed_hat);
    var closedHat = new Tone.NoiseSynth({
      noise: { type: 'white' },
      envelope: { attack: 0.001, decay: 0.045, sustain: 0, release: 0.01 },
    }).connect(hatFilter);

    var openFilter = new Tone.Filter(6500, 'highpass').connect(gains.open_hat);
    var openHat = new Tone.NoiseSynth({
      noise: { type: 'white' },
      envelope: { attack: 0.001, decay: 0.28, sustain: 0, release: 0.08 },
    }).connect(openFilter);

    var clap = new Tone.NoiseSynth({
      noise: { type: 'pink' },
      envelope: { attack: 0.001, decay: 0.12, sustain: 0, release: 0.05 },
    }).connect(new Tone.Filter(1400, 'bandpass').connect(gains.clap));

    voices.kick = function (time, vel) {
      kick.triggerAttackRelease('C1', '8n', time, vel);
    };
    voices.snare = function (time, vel) {
      snareNoise.triggerAttackRelease('16n', time, vel);
      snareBody.triggerAttackRelease(190, '32n', time, vel * 0.6);
    };
    voices.closed_hat = function (time, vel) {
      openHat.triggerRelease(time); // closed hat chokes the open hat
      closedHat.triggerAttackRelease('32n', time, vel);
    };
    voices.open_hat = function (time, vel) {
      openHat.triggerAttackRelease('8n', time, vel);
    };
    voices.clap = function (time, vel) {
      // Three quick bursts then a tail gives the "multiple hands" clap.
      clap.triggerAttackRelease('64n', time, vel * 0.7);
      clap.triggerAttackRelease('64n', time + 0.012, vel * 0.8);
      clap.triggerAttackRelease('16n', time + 0.026, vel);
    };

    var silence = function () {
      var now = Tone.now();
      [kick, snareNoise, snareBody, closedHat, openHat, clap].forEach(function (s) {
        try {
          s.triggerRelease(now);
        } catch (e) { /* releasing an idle synth is harmless */ }
      });
    };

    var nodes = [kick, snareNoise, snareBody, closedHat, openHat, clap, hatFilter, openFilter];
    Object.keys(gains).forEach(function (k) { nodes.push(gains[k]); });

    return { voices: voices, gains: gains, silence: silence, nodes: nodes };
  }

  function applyGains() {
    var e = requireEngine();
    TRACK_IDS.forEach(function (id) {
      var target = e.muted[id] ? 0 : e.volumes[id];
      e.gains[id].gain.rampTo(target, 0.03);
    });
  }

  function onStep(time, index) {
    var e = engine;
    if (!e) return;
    TRACK_IDS.forEach(function (id) {
      var row = e.pattern[id];
      if (row && row[index] === true) {
        e.voices[id](time, id === 'kick' || id === 'snare' ? 1 : 0.9);
      }
    });
    var stepSeconds = Tone.Time('16n').toSeconds();
    // Non-looping playback: stop right after the last step of the bar.
    var endsBar = index === STEPS - 1 && !e.loop;
    if (endsBar) Tone.Transport.stop(time + stepSeconds);
    atAudioTime(time, function () {
      if (!engine || engine.disposed || engine.state !== 'playing') return;
      engine.step = index;
      emit();
    });
    if (endsBar) {
      atAudioTime(time + stepSeconds, function () {
        if (!engine || engine.disposed || engine.state !== 'playing') return;
        engine.step = -1;
        setState('stopped');
      });
    }
  }

  function parseAndValidatePattern(json) {
    var parsed = typeof json === 'string' ? JSON.parse(json) : json;
    if (!parsed || typeof parsed !== 'object') throw new Error('Pattern must be an object.');
    var tracks = emptyPattern();
    TRACK_IDS.forEach(function (id) {
      var row = parsed[id];
      if (!Array.isArray(row) || row.length !== STEPS) {
        throw new Error('Track "' + id + '" must have exactly ' + STEPS + ' steps.');
      }
      tracks[id] = row.map(function (v) { return v === true; });
    });
    return tracks;
  }

  var api = {
    version: 1,

    /** Creates the audio graph. Must be called from a user gesture. Idempotent. */
    init: function () {
      if (initPromise) return initPromise;
      initPromise = (async function () {
        if (typeof Tone === 'undefined') {
          throw new Error('Tone.js failed to load.');
        }
        await Tone.start(); // resumes the AudioContext (autoplay policy)
        if (Tone.getContext().state !== 'running') {
          await Tone.getContext().resume();
        }
        var master = new Tone.Gain(0.8).toDestination();
        var built = buildVoices(master);
        var seq = new Tone.Sequence(onStep, Array.from({ length: STEPS }, function (_, i) { return i; }), '16n');
        seq.loop = true;
        seq.start(0);
        Tone.Transport.bpm.value = 120;
        engine = {
          state: 'stopped',
          step: -1,
          loop: true,
          disposed: false,
          pattern: emptyPattern(),
          volumes: { kick: 0.8, snare: 0.8, closed_hat: 0.6, open_hat: 0.5, clap: 0.7 },
          muted: {},
          master: master,
          seq: seq,
          voices: built.voices,
          gains: built.gains,
          silence: built.silence,
          nodes: built.nodes,
        };
        applyGains();
      })().catch(function (err) {
        initPromise = null; // allow a retry after failure
        throw err;
      });
      return initPromise;
    },

    isReady: function () { return !!engine; },

    play: function () {
      var e = requireEngine();
      if (Tone.getContext().state !== 'running') Tone.getContext().resume();
      if (Tone.Transport.state === 'started') return;
      Tone.Transport.start('+0.05');
      setState('playing');
    },

    pause: function () {
      var e = requireEngine();
      if (Tone.Transport.state !== 'started') return;
      Tone.Transport.pause();
      clearTimers();
      e.silence();
      setState('paused');
    },

    stop: function () {
      var e = requireEngine();
      Tone.Transport.stop();
      clearTimers();
      e.silence();
      e.step = -1;
      if (e.state === 'stopped') emit(); else setState('stopped');
    },

    setBpm: function (bpm) {
      requireEngine();
      var n = Number(bpm);
      if (!isFinite(n)) throw new Error('BPM must be a number.');
      Tone.Transport.bpm.rampTo(clamp(Math.round(n), MIN_BPM, MAX_BPM), 0.05);
    },

    /** Replaces the whole pattern; takes effect on the next scheduled step. */
    setPattern: function (json) {
      requireEngine().pattern = parseAndValidatePattern(json);
    },

    setTrackVolume: function (trackId, volume) {
      var e = requireEngine();
      if (TRACK_IDS.indexOf(trackId) < 0) throw new Error('Unknown track: ' + trackId);
      e.volumes[trackId] = clamp(Number(volume) || 0, 0, 1);
      applyGains();
    },

    setTrackMuted: function (trackId, muted) {
      var e = requireEngine();
      if (TRACK_IDS.indexOf(trackId) < 0) throw new Error('Unknown track: ' + trackId);
      e.muted[trackId] = !!muted;
      applyGains();
    },

    setMasterVolume: function (volume) {
      var e = requireEngine();
      e.master.gain.rampTo(clamp(Number(volume) || 0, 0, 1), 0.03);
    },

    setLoop: function (loop) {
      requireEngine().loop = !!loop;
    },

    /** Plays one track's sound immediately (used when toggling a step on). */
    preview: function (trackId) {
      var e = requireEngine();
      if (TRACK_IDS.indexOf(trackId) < 0) throw new Error('Unknown track: ' + trackId);
      e.voices[trackId](Tone.now(), 0.9);
    },

    /** Single listener, replaced on each call. Pass null to remove. */
    setStatusListener: function (fn) {
      statusListener = typeof fn === 'function' ? fn : null;
    },

    getStatus: function () {
      return engine ? { state: engine.state, step: engine.step } : { state: 'uninitialized', step: -1 };
    },

    /** Releases all audio resources. init() may be called again afterwards. */
    dispose: function () {
      var e = engine;
      statusListener = null;
      if (!e) return;
      e.disposed = true;
      engine = null;
      initPromise = null;
      try {
        Tone.Transport.stop();
        Tone.Transport.cancel(0);
        clearTimers();
        e.silence();
        e.seq.dispose();
        e.nodes.forEach(function (n) { n.dispose(); });
        e.master.dispose();
      } catch (err) {
        console.error('[BeatGridAudio] dispose failed', err);
      }
    },
  };

  window.BeatGridAudio = api;
})();
