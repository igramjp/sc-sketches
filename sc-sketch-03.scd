// ============================================================
// sc-sketch-03.scd
// 黄鐘の雨 ― ジェネレーティブ・アンビエント (黄鐘調・遅)
// ------------------------------------------------------------
// 数秒に一滴の雨音が、長い周期のこだまとなって薄れていく:
//   ・雨の間隔   5-14秒
//   ・こだま周期 32秒 × 最大5回 (減衰 0.66)
//   ・滴の減衰   5-9秒 / 波紋 4-7秒
//   ・残響 t60   15秒
//
// 調律: A=430Hz / 黄鐘調 (A B D E F#) ― 主音A=基準ピッチそのもの
// パッド: A2 E3 A3 E4 の空虚5度 (三度なし)
//
// 信号順序: ~srcG -> ~revG(JPverb insert) -> ~mstG (Group.afterで保証)
// 演算子: SCは優先順位なし全て左→右。* と ** 混在は必ず括弧。
//
// 評価順: [0]前の演奏の掃除 -> [1]ブート&定義 -> [2]雨が降り始める
//         [3]ライブ操作例 / [4]停止 / [5]MIDI(任意)
// ============================================================


// ============================================================
// [0] 前の演奏が残っている場合の掃除 (新規に始めるときだけ)
// ============================================================
(
~conductor !? { ~conductor.stop };
~weaveTask !? { ~weaveTask.stop };
~kotoRain !? { ~kotoRain.stop };
~gongs !? { ~gongs.stop };
~rain !? { ~rain.stop };
~raining = false;
~sho = nil;
~ghosts !? { ~ghosts.do { |g| g.set(\gate, 0) }; ~ghosts = List.new };
~weaveSyn !? { ~weaveSyn.set(\gate, 0); ~weaveSyn = nil };
~pad !? { ~pad.set(\gate, 0); ~pad = nil };
~revSyn !? { ~revSyn.free; ~revSyn = nil };
~mst !? { ~mst.free; ~mst = nil };
~srcG !? { ~srcG.freeAll; ~srcG = nil };
~mixBus !? { ~mixBus.free; ~mixBus = nil };
)


// ============================================================
// [1] ブート・SynthDef・グループ・バス
// ============================================================
(
~outDev = ["Multi-Output Device"]
    .detect { |d| ServerOptions.outDevices.includesEqual(d) };
if(~outDev.notNil) { s.options.outDevice_(~outDev) };
s.options.numInputBusChannels_(0);
s.options.numWireBufs_(256);
s.options.memSize_(8192 * 64);

s.waitForBoot({

    SynthDef(\drop, { |out=0, freq=430, amp=0.2, dec=4.5, bright=0.35, pan=0|
        var sig, env;
        env = EnvGen.ar(Env.perc(0.012, dec, 1, -5), doneAction: 2);
        sig = SinOsc.ar(freq)
            + (SinOsc.ar(freq * 1.003) * 0.3)
            + (SinOsc.ar(freq * 2) * (bright * 0.4))
            + (SinOsc.ar(freq * 3) * (bright * 0.1));
        sig = LPF.ar(sig, (freq * 6).clip(800, 9000));
        Out.ar(out, Pan2.ar(sig * env * amp * 0.45, pan));
    }).add;

    SynthDef(\ripple, { |out=0, freq=215, amp=0.04, dur=4, pan=0|
        var sig, env, wobble;
        env = EnvGen.ar(
            Env([0, 1, 0], [(dur * 0.35), (dur * 0.65)], \sine), doneAction: 2);
        wobble = SinOsc.kr(Line.kr(5, 1.2, dur)).range(0.55, 1);
        sig = SinOsc.ar(freq * [0.9985, 1.0015]);
        Out.ar(out, Balance2.ar(sig[0], sig[1], pan) * env * wobble * amp);
    }).add;

    SynthDef(\pad, { |out=0, amp=0, gate=1, atk=25, rel=30|
        var freqs, env, sig, filt;
        freqs = \freqs.kr(Array.fill(4, 107.5));
        env = EnvGen.kr(Env.asr(atk, 1, rel, \sine), gate, doneAction: 2);
        sig = Array.fill(4, { |i|
            var f, breath;
            f = freqs[i];
            breath = LFNoise1.kr(ExpRand(0.02, 0.05)).range(0.3, 1.0);
            ((SinOsc.ar(f) + SinOsc.ar(f * 1.002)) * 0.5
                + (LFTri.ar(f * 2) * 0.07))
                * breath
        });
        sig = Splay.ar(sig, 0.6);
        filt = SinOsc.kr(0.03, Rand(0, 2pi)).range(250, 900);
        sig = LPF.ar(sig, filt);
        Out.ar(out, sig * env * amp.lag(8) * 0.22);
    }).add;

    SynthDef(\jpverbIns, { |in=0, mix=0.65, t60=12, damp=0.35, size=2.8,
                            early=0.7, modDepth=0.08, modFreq=1.2,
                            low=1.0, mid=1.0, high=0.5,
                            lowcut=250, highcut=3000|
        var dry, wet, m;
        m   = mix.lag(4);
        dry = In.ar(in, 2);
        wet = JPverb.ar(dry, t60.lag(4), damp, size, early,
                        modDepth, modFreq, low, mid, high, lowcut, highcut);
        wet = LeakDC.ar(wet);
        ReplaceOut.ar(in, (dry * (1 - m)) + (wet * m));
    }).add;

    SynthDef(\master, { |in=0, out=0, amp=1, ceiling=0.95|
        var sig;
        sig = In.ar(in, 2);
        Out.ar(out, Limiter.ar(sig * amp.lag(2), ceiling));
    }).add;

    s.sync;

    ~srcG  = Group.new(s);
    ~revG  = Group.after(~srcG);
    ~mstG  = Group.after(~revG);
    ~mixBus = Bus.audio(s, 2);
});
)


// ============================================================
// [2] 雨が降り始める
// ============================================================
(
~a4 = 430;
~mcps = { |n| ~a4 * (2 ** ((n - 69) / 12)) };
~oshikiPC = [9, 11, 2, 4, 6];                     // 黄鐘調: A B D E F#
// 雨つぶの音域: 中域 ~C5 付近に山なり
~dropPool = (52..97).select { |n| ~oshikiPC.includes(n % 12) };
~dropWeights = ~dropPool.collect { |n|
    1 / (1 + (((n - 72) / 10).squared))
}.normalizeSum;

// --- インスタンス (なければ作る / 再評価時は再利用) --------------
~revSyn = ~revSyn ?? { Synth(\jpverbIns, [\in, ~mixBus, \mix, 0.65], ~revG) };
~mst    = ~mst    ?? { Synth(\master, [\in, ~mixBus, \out, 0, \amp, 1.0], ~mstG) };
~revSyn.set(\t60, 15);                            // 残響は深めに

// --- パッド (再評価時: 旧パッドは30秒で暮れ、新パッドが明ける) ---
~pad !? { ~pad.set(\gate, 0) };
~pad = Synth(\pad, [\out, ~mixBus, \amp, 0, \atk, 30], ~srcG);
~pad.setn(\freqs, [45, 52, 57, 64].collect { |n| ~mcps.(n) });   // A2 E3 A3 E4
~pad.set(\amp, 0.8);

// --- 生成エンジンの心臓 (黄鐘調・遅) ----------------------------
~loopDur  = 32;                                   // こだまの周期
~echoes   = 5;
~echoFade = 0.66;                                 // こだまの減衰率
~raining  = true;

~drop = { |note, amp = 0.2, pan = 0, gen = 0|
    // 黄鐘調にない音は静かに見送る
    if(~raining and: { ~srcG.notNil }
        and: { ~oshikiPC.includes(note % 12) }) {
        var freq = ~mcps.(note);
        Synth(\drop, [
            \out, ~mixBus, \freq, freq,
            \amp, amp, \dec, rrand(5.0, 9.0),
            \bright, (0.35 * (0.7 ** gen)),
            \pan, pan
        ], ~srcG);
        Synth(\ripple, [
            \out, ~mixBus, \freq, (freq * 0.5),
            \amp, (amp * 0.16), \dur, rrand(4.0, 7.0),
            \pan, (pan * 0.5)
        ], ~srcG);
        if((gen < ~echoes) and: { (amp * ~echoFade) > 0.018 }) {
            SystemClock.sched(~loopDur, {
                ~drop.(note, (amp * ~echoFade),
                       ((pan * -0.7) + rrand(-0.15, 0.15)), (gen + 1));
                nil
            });
        };
    };
};

// --- 生成の雨: 5〜14秒に一滴 --------------------------------------
~rain !? { ~rain.stop };
~rain = Task({
    inf.do {
        ~drop.(
            ~dropPool.wchoose(~dropWeights),
            rrand(0.12, 0.26),
            rrand(-0.7, 0.7)
        );
        rrand(5.0, 14.0).wait;
    };
}).play(SystemClock);
)


// ============================================================
// [3] ライブ操作の例 (1行ずつ評価)
// ============================================================
~drop.(69);                       // 手でタップ (A4 = 430Hzちょうど)
~drop.(64, 0.3, -0.5);            // E4 を強めに左から
[57, 64, 69].do { |n| ~drop.(n, 0.16, rrand(-0.6, 0.6)) };  // A-E-A の雨
~loopDur = 40;                    // こだまをさらに遅く
~echoFade = 0.78;                 // こだまを長持ちさせる
~rain.stop;                       // 自動の雨を止めて手動タップのみに
~rain.play(SystemClock);          // 雨を再開
~revSyn.set(\t60, 20);            // 残響を最深に
~pad.set(\amp, 0);                // パッドを消して雨だけに


// ============================================================
// [4] 停止 (パッドは30秒、こだまは静かに死んでいく)
// ============================================================
(
~rain !? { ~rain.stop };
~raining = false;
~pad.set(\gate, 0);
)

// 完全クリーンアップ (静寂になってから)
(
MIDIdef.freeAll;
~revSyn.free; ~mst.free;
~srcG.freeAll;
~mixBus.free;
)


// ============================================================
// [5] MIDI ― 鍵盤がタップになる (任意)
// ------------------------------------------------------------
//   MIDI鍵盤: 弾いた音が黄鐘調にスナップされ、一滴としてループへ。
// ============================================================
(
MIDIClient.initialized.not.if { MIDIClient.init };
MIDIIn.connectAll;
~lin = { |v, lo, hi| lo + ((v / 127) * (hi - lo)) };
~xpn = { |v, lo, hi| lo * ((hi / lo) ** (v / 127)) };  // 優先順位なし→括弧必須

// 最寄りの黄鐘調音へスナップ
~snap = { |n|
    (0..6).collect { |d| [n + d, n - d] }.flat
        .detect { |m| ~oshikiPC.includes(m % 12) }
};

MIDIdef.noteOn(\keyTap, { |vel, num|
    ~drop.(~snap.(num), ((vel / 127) * 0.3).max(0.06), rrand(-0.6, 0.6));
});

MIDIdef.cc(\rnF1, { |v| ~pad.set(\amp, ~lin.(v, 0, 1.2)) }, 5);
MIDIdef.cc(\rnF2, { |v| ~echoFade = ~lin.(v, 0.3, 0.85) }, 6);
MIDIdef.cc(\rnF6, { |v| ~revSyn.set(\mix, ~lin.(v, 0, 1.0)) }, 10);
MIDIdef.cc(\rnF7, { |v| ~revSyn.set(\t60, ~xpn.(v, 3.0, 22.0)) }, 11);
MIDIdef.cc(\rnF8, { |v| ~mst.set(\amp, ~lin.(v, 0, 1.2)) }, 12);
MIDIdef.cc(\rnK6, { |v| ~loopDur = ~lin.(v, 16, 48) }, 18);      // こだま周期
)
