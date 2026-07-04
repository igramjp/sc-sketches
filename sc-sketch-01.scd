// ============================================================
// sc-sketch-01.scd
// "glass halo"
// ------------------------------------------------------------
// SuperCollider Sketch #1 | igram lab | 音響音楽研究所
// article: https://note.com/igram/n/n59c3a93d442f
//
// 疎らなフェルトピアノの一音が、純サイン波の光輪(ハロ)に
// 包まれて、ゆっくり沈んでいく。
// Am9 → Fmaj9 → Cmaj9 → Em9 の4和音(各22秒)が終わりなく循環する。
//
// 調律: A=430Hz (クリックとサブの周波数もすべて430から導出)
// 依存: sc3-plugins (JPverb, Greyhole)
//
// 演奏: [1]ブート&定義 → [2]開始 (部品が約90秒かけて順に
//       入ってくる) → [3]差し替えメニューを自由に評価
//       → [4]停止 / [5]完全掃除
// ============================================================


// [1] ブート & 音色の定義 ------------------------------------
(
s.options.numInputBusChannels_(0);
s.options.numWireBufs_(256);
s.options.memSize_(8192 * 64);

s.waitForBoot({
    ~d_a4 = 430;
    ~d_mcps = { |n| ~d_a4 * (2 ** ((n - 69) / 12)) };

    SynthDef(\d_fpiano, { |out=0, freq=220, amp=0.2, rel=9, pan=0|
        var partials = #[1, 2.001, 2.998, 4.004, 5.007, 6.012];
        var pamps    = #[1, 0.26, 0.11, 0.05, 0.025, 0.012];
        var decays   = #[1, 0.48, 0.32, 0.22, 0.16, 0.11];
        var body, hammer, kill, sig;
        body = Mix(partials.collect { |p, i|
            SinOsc.ar((freq * p), Rand(0, 0.3)) * pamps[i]
                * EnvGen.ar(Env.perc(0.005, (rel * decays[i]), curve: -5));
        });
        hammer = LPF.ar(WhiteNoise.ar, (freq * 3).clip(200, 3500))
            * EnvGen.ar(Env.perc(0.001, 0.035)) * 0.07;
        kill = EnvGen.kr(Env([1, 1, 0], [rel, 0.5]), doneAction: 2);
        sig = ((body + hammer) * amp * 0.5);
        Out.ar(out, Pan2.ar(sig * kill, pan));
    }).add;

    SynthDef(\d_clk, { |out=0, freq=6450, amp=0.08, dec=0.004, pan=0|
        var e = EnvGen.ar(Env.perc(0.0001, dec, 1, -10), doneAction: 2);
        var sig = (SinOsc.ar(freq) * 0.75)
            + (HPF.ar(WhiteNoise.ar, (freq * 0.8)) * 0.25);
        Out.ar(out, Pan2.ar(sig * e * amp, pan));
    }).add;

    SynthDef(\d_pip, { |out=0, freq=1720, amp=0.06, dec=1.2, pan=0|
        var e = EnvGen.ar(Env.perc(0.002, dec, 1, -6), doneAction: 2);
        Out.ar(out, Pan2.ar(SinOsc.ar(freq) * e * amp, pan));
    }).add;

    SynthDef(\d_subp, { |out=0, freq=53.75, amp=0.3, dec=0.9|
        var t = EnvGen.ar(Env.perc(0.004, dec, 1, -6), doneAction: 2);
        var sig = SinOsc.ar(freq) + (SinOsc.ar(freq * 2) * 0.1);
        Out.ar(out, (LPF.ar(sig, 160) * t * amp) ! 2);
    }).add;

    s.sync;
});
)


// [2] 開始 ---------------------------------------------------
(
TempoClock.default.tempo = 63 / 60;

~d_chords = [
    [45, 52, 55, 59, 60, 64],
    [41, 48, 52, 55, 57, 60],
    [48, 55, 59, 62, 64, 67],
    [40, 47, 50, 54, 55, 59]
];
~d_idx = 0;
~d_chord = ~d_chords[0];

Ndef(\d_halo).fadeTime = 10;
~d_setHalo = {
    Ndef(\d_halo, {
        var sig = ~d_chord.drop(2).collect { |n|
            var f = ~d_mcps.(n + 12) * LFNoise1.kr(0.05).range(0.9993, 1.0007);
            SinOsc.ar(f) * LFNoise1.kr(ExpRand(0.03, 0.09)).range(0.15, 1)
        };
        var sparkle = SinOsc.ar(~d_mcps.(~d_chord.last + 24))
            * LFNoise1.kr(0.04).range(0, 1).pow(3) * 0.25;
        (Splay.ar(sig, 0.6) + Pan2.ar(sparkle, LFNoise1.kr(0.02))) * 0.05
    });
};
~d_setHalo.value;

Ndef(\d_fp).quant = 0;
Ndef(\d_fp, Pbind(
    \instrument, \d_fpiano,
    \dur,  Pwrand([2, 3, 4, 6, Rest(3), Rest(5)],
        [3, 3, 2, 1, 2, 1].normalizeSum, inf),
    \freq, Pfunc {
        if(0.12.coin) { ~d_mcps.(~d_chord[0] - 12) }
        { ~d_mcps.(~d_chord.drop(1).choose + [0, 0, 0, 12].choose) }
    },
    \amp,  Pwhite(0.1, 0.28),
    \rel,  Pwhite(7.0, 10.0),
    \pan,  Pwhite(-0.25, 0.25)
));

Ndef(\d_hiss, {
    HPF.ar(BrownNoise.ar(1 ! 2), 6000)
        * LFNoise1.kr(0.05).range(0.15, 1) * 0.006
});

Ndef(\d_mix).fadeTime = 6;
Ndef(\d_mix, {
    (Ndef.ar(\d_fp,   2) * \fpAmp.kr(1))
    + (Ndef.ar(\d_halo, 2) * \haloAmp.kr(1))
    + (Ndef.ar(\d_grid, 2) * \gridAmp.kr(1))
    + (Ndef.ar(\d_pips, 2) * \pipsAmp.kr(1))
    + (Ndef.ar(\d_sub,  2) * \subAmp.kr(1))
    + (Ndef.ar(\d_hiss, 2) * \hissAmp.kr(1))
});
Ndef(\d_mix)[1] = \filter -> { |in|
    JPverb.ar(in, \t60.kr(7), 0.35, \vsize.kr(3.2), 0.8)
};
Ndef(\d_mix)[9] = \filter -> { |in| Limiter.ar(in, 0.95) };
Ndef(\d_mix).set(\wet1, 0.38, \wet9, 1);
Ndef(\d_mix).play(vol: 1);

~d_chordTask !? { ~d_chordTask.stop };
~d_chordTask = Task({
    inf.do {
        22.wait;
        ~d_idx = ((~d_idx + 1) % ~d_chords.size);
        ~d_chord = ~d_chords[~d_idx];
        ~d_setHalo.value;
    };
}).play(SystemClock);

~d_growTask !? { ~d_growTask.stop };
~d_growTask = Task({
    30.wait;
    Ndef(\d_sub, Pbind(
        \instrument, \d_subp,
        \dur,  Pseq([Rest(1), 1, Rest(2.5), 1, Rest(2.5)], inf),
        \freq, Pfunc { ~d_mcps.(~d_chord[0] - 12) },
        \dec,  Prand([0.7, 0.9], inf),
        \amp,  Pwhite(0.14, 0.2)
    ));

    30.wait;
    Ndef(\d_grid).quant = 1;
    Ndef(\d_grid, Pbind(
        \instrument, \d_clk,
        \dur,  Pwrand([0.25, Rest(0.25), Rest(0.75), Rest(1.75)],
            [0.28, 0.4, 0.2, 0.12].normalizeSum, inf),
        \freq, Prand([4300, 5375, 6450, 8600], inf),
        \dec,  Pwhite(0.002, 0.009),
        \amp,  Pwhite(0.04, 0.1),
        \pan,  Pseq([-0.6, 0.5, -0.3, 0.7], inf)
    ));

    30.wait;
    Ndef(\d_pips, Pbind(
        \instrument, \d_pip,
        \dur,  Pwhite(3.0, 9.0),
        \freq, Pfunc { ~d_mcps.(~d_chord.drop(3).choose + 24) },
        \dec,  Pwhite(0.8, 1.8),
        \amp,  Pwhite(0.03, 0.06),
        \pan,  Pwhite(-0.7, 0.7)
    ));
}).play(SystemClock);

)


// [3] 差し替えメニュー ---------------------------------------
// 演奏中にどれかを評価すると、音を止めずに入れ替わる

// 空間: Greyhole
(
Ndef(\d_mix)[1] = \filter -> { |in|
    Greyhole.ar(in, \dtime.kr(0.6), 0.3, \size.kr(3.0), 0.7, \fb.kr(0.9))
};
Ndef(\d_mix).set(\wet1, 0.5);
)

// 空間: コムディレイ
(
Ndef(\d_mix)[1] = \filter -> { |in|
    in + (LPF.ar(CombL.ar(in, 1, \dtime.kr(0.37), \dfb.kr(3.5)), 3200) * 0.5)
};
Ndef(\d_mix).set(\wet1, 0.6);
)

// 空間: JPverbに戻す
(
Ndef(\d_mix)[1] = \filter -> { |in|
    JPverb.ar(in, \t60.kr(7), 0.35, \vsize.kr(3.2), 0.8)
};
Ndef(\d_mix).set(\wet1, 0.38);
)

// クリック: データ転送バースト版
(
Ndef(\d_grid, Pbind(
    \instrument, \d_clk,
    \dur, Prand([
        Pseq([0.125, 0.125, 0.125, 0.125, Rest(1.5)], 1),
        Pseq([0.25, Rest(0.75)], 1),
        Pseq([Rest(2)], 1)
    ], inf),
    \freq, Prand([4300, 5375, 6450, 8600, 10750], inf),
    \dec,  Pwhite(0.002, 0.006),
    \amp,  Pwhite(0.05, 0.11),
    \pan,  Pwhite(-0.7, 0.7)
));
)

// クリック: ほとんど沈黙
(
Ndef(\d_grid, Pbind(
    \instrument, \d_clk,
    \dur,  Pwrand([0.25, Rest(1.75), Rest(3.75)], [0.15, 0.5, 0.35], inf),
    \freq, Prand([6450, 8600], inf),
    \dec,  0.003, \amp, Pwhite(0.03, 0.07), \pan, Pwhite(-0.5, 0.5)
));
)

// ピアノ: 動きを増やす
(
Ndef(\d_fp, Pbind(
    \instrument, \d_fpiano,
    \dur,  Pwrand([1, 1.5, 2, 3, Rest(2)], [2, 3, 3, 1, 2].normalizeSum, inf),
    \freq, Pfunc { ~d_mcps.(~d_chord.drop(1).choose + [0, 0, 12].choose) },
    \amp,  Pwhite(0.09, 0.22), \rel, Pwhite(6.0, 9.0), \pan, Pwhite(-0.3, 0.3)
));
)

// ハロの声部を高く開く
(
~d_setHalo = {
    Ndef(\d_halo, {
        var sig = ~d_chord.drop(2).collect { |n|
            var f = ~d_mcps.(n + 24) * LFNoise1.kr(0.05).range(0.9995, 1.0005);
            SinOsc.ar(f) * LFNoise1.kr(ExpRand(0.03, 0.09)).range(0.1, 1)
        };
        Splay.ar(sig, 0.8) * 0.035
    });
};
~d_setHalo.value;
)


// [4] 停止 (15秒フェードアウト) ------------------------------
(
~d_chordTask !? { ~d_chordTask.stop };
~d_growTask  !? { ~d_growTask.stop };
Ndef(\d_mix).end(15);
)


// [5] 完全掃除 -----------------------------------------------
(
[\d_fp, \d_halo, \d_grid, \d_pips, \d_sub, \d_hiss, \d_mix].do { |k| Ndef(k).clear };
)
