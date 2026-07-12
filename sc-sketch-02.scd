// ============================================================
// sc-sketch-02.scd
// "tide"
// ------------------------------------------------------------
// SuperCollider Sketch #2 | igram lab | 音響音楽研究所
//
// #1 glass halo が「430というひとつの定数から全周波数を導く」
// だったのに対し、これは「~tide というひとつの変数から世界の
// 全状態を導く」。定数だった数字が、つまみになる。
//
//     ~tide.(0.8);     // 0.0 (大干潮) 〜 1.0 (大潮)
//
// 潮が満ちると笙の声部が階段状に浸水し、海の底が脈打ち、
// 水面に光が瞬く。潮が引くと霧が立ちこめ、岩場に鉦鼓が響く。
// 放っておくと「月」が12分周期で勝手に潮を動かす。~tide.() を
// 評価した瞬間から3分間は潮はあなたのもの。
//
// 調律: A=430Hz (基音 53.75Hz の倍音格子のみ)
// 依存: sc3-plugins (JPverb, Greyhole)
//
// 演奏: [1]ブート&定義 → [2]開始 (部品が約80秒かけて順に
//       入ってくる) → [3]潮見表を自由に評価
//       → [4]停止 / [5]完全掃除
// ============================================================


// [1] ブート & 音色の定義 ------------------------------------
// "Server exited with exit code 0" が出るときは、outDevice を
// Audio MIDI 設定の名前に合わせ、s.quit; してから再評価
(
s.options.numInputBusChannels_(0);
s.options.numWireBufs_(256);
s.options.memSize_(8192 * 64);

~t_fund = (430 / 8);            // 53.75Hz (言語側なのでブートを待たない)

s.waitForBoot({
    SynthDef(\t_kane, { |out=0, freq=645, amp=0.12, rel=7, pan=0|
        var hit  = BPF.ar(WhiteNoise.ar, (freq * 2).clip(100, 8000), 0.3)
            * EnvGen.ar(Env.perc(0.001, 0.05)) * 0.35;
        var body = (SinOsc.ar(freq) + (SinOsc.ar(freq + 1.7) * 0.8))
            + (SinOsc.ar((freq * 3.007)) * 0.3)
            + (SinOsc.ar((freq * 5.019)) * 0.09);
        var env  = EnvGen.kr(Env.perc(0.002, rel, 1, -6), doneAction: 2);
        Out.ar(out, Pan2.ar(((body * 0.3 * env) + (hit * env)) * amp, pan));
    }).add;

    SynthDef(\t_pip, { |out=0, freq=1720, amp=0.05, dec=1.5, pan=0|
        var e = EnvGen.ar(Env.perc(0.002, dec, 1, -6), doneAction: 2);
        Out.ar(out, Pan2.ar(SinOsc.ar(freq) * e * amp, pan));
    }).add;

    s.sync;
});
)


// [2] 開始 ---------------------------------------------------
(
// 潮位バス (Lag 10秒 ― 潮は急がない) と、唯一のつまみ ~tide
~t_now = 0.12;                              // 言語側ミラー (Pbind系が読む)
Ndef(\t_tideBus, { Lag.kr(\v.kr(0.12), \lagT.kr(10)) });

~t_manualUntil = 0;
~tide = { |x|
    ~t_now = x.clip(0.0, 1.0);
    ~t_manualUntil = (Main.elapsedTime + 180);
    Ndef(\t_tideBus).set(\v, ~t_now);
};
~tideAuto = { ~t_manualUntil = 0 };

// 和声 (基音53.75Hzの倍音番号。28秒で巡回)
~t_sets = [
    [6, 8, 9, 12],      // E A B E
    [4, 6, 7, 9],       // A E G B
    [3, 8, 10, 12],     // E A C# E
    [4, 6, 8, 9]        // A E A B
];
~t_idx = 0;
~t_chord = ~t_sets[0];

// 笙クラスタ: 潮が上がるたび、ひとつ上の倍音がゆっくり灯る
Ndef(\t_sho).fadeTime = 10;
~t_setSho = {
    var lad = (~t_chord ++ (~t_chord * 2) ++ [(~t_chord[0] * 4)])
        .asSet.asArray.sort;                // 倍音の梯子 (下から浸かる)
    var n = lad.size;
    Ndef(\t_sho, {
        var tide = Ndef.kr(\t_tideBus, 1);
        var vs = lad.collect { |h, i|
            var f = (~t_fund * h * 2);
            var gate = ((tide * (n + 1)) - i).clip(0, 1);
            var breath = LFNoise1.kr(ExpRand(0.04, 0.1)).range(0.4, 1);
            (SinOsc.ar(f, Rand(0, 2pi))
                + (SinOsc.ar((f + Rand(0.04, 0.13)), Rand(0, 2pi)) * 0.55))
                * gate.pow(1.5) * breath * ((i + 3).reciprocal)
        };
        Splay.ar(vs, 0.75) * 0.5
    });
};
~t_setSho.value;

// 霧: 干潮の岩場に立ちこめる (和音の倍音だけが亡霊のように鳴る)
Ndef(\t_fog).fadeTime = 8;
~t_setFog = {
    var set = ~t_chord;
    Ndef(\t_fog, {
        var tide = Ndef.kr(\t_tideBus, 1);
        var wisps = set.collect { |h|
            BPF.ar(PinkNoise.ar, (~t_fund * h * 4), 0.002, 150)
                * LFNoise1.kr(ExpRand(0.05, 0.12)).range(0.1, 1)
        };
        var floor = LPF.ar(PinkNoise.ar(0.15 ! 2), 430);
        ((Splay.ar(wisps, 0.7) * 0.8) + floor)
            * ((1 - tide).pow(1.5) * 0.5 + 0.04)
    });
};
~t_setFog.value;

// 波音: ヒスが9秒周期で寄せては返す (満潮ほど大きく)
Ndef(\t_hiss, {
    var tide = Ndef.kr(\t_tideBus, 1);
    var wash = SinOsc.kr((1 / 9), Rand(0, 2pi)).range(0, 1).pow(2);
    HPF.ar(BrownNoise.ar(1 ! 2), 6000)
        * LFNoise1.kr(0.05).range(0.15, 1)
        * (0.005 + (wash * tide * 0.01))
});

// 鉦鼓: 干潮の岩場に響き、潮が満ちると水没して黙る
Ndef(\t_gong).quant = 0;
Ndef(\t_gong, Pbind(
    \instrument, \t_kane,
    \dur,  Pfunc { ((3.0 + (~t_now * 15)) * rrand(0.6, 1.5)) },
    \freq, Pfunc { (~t_fund * [8, 9, 12, 16].choose) },
    \rel,  Pwhite(5.0, 8.0),
    \amp,  Pfunc { (((1 - ~t_now).pow(1.3) * rrand(0.5, 1.0) * 0.3) + 0.008) },
    \pan,  Pwhite(-0.6, 0.6)
));

// 合流 → リバーブ席 [1] → リミッタ [9] (\t_sub \t_glint は席だけ先に配線)
Ndef(\t_mix).fadeTime = 6;
Ndef(\t_mix, {
    (Ndef.ar(\t_sho,   2) * \shoAmp.kr(1))
    + (Ndef.ar(\t_fog,   2) * \fogAmp.kr(1))
    + (Ndef.ar(\t_sub,   2) * \subAmp.kr(1))
    + (Ndef.ar(\t_gong,  2) * \gongAmp.kr(1))
    + (Ndef.ar(\t_glint, 2) * \glintAmp.kr(1))
    + (Ndef.ar(\t_hiss,  2) * \hissAmp.kr(1))
});
Ndef(\t_mix)[1] = \filter -> { |in|
    JPverb.ar(in, \t60.kr(8), 0.35, \vsize.kr(3.5), 0.8)
};
Ndef(\t_mix)[9] = \filter -> { |in| Limiter.ar(in, 0.95) };
Ndef(\t_mix).set(\wet1, 0.36, \wet9, 1);
Ndef(\t_mix).play(vol: 1);

// 和声の巡回 (28秒ごと。笙と霧をソースごと再評価 = ゆっくり渡る)
~t_chordTask !? { ~t_chordTask.stop };
~t_chordTask = Task({
    inf.do {
        28.wait;
        ~t_idx = ((~t_idx + 1) % ~t_sets.size);
        ~t_chord = ~t_sets[~t_idx];
        ~t_setSho.value;
        ~t_setFog.value;
    };
}).play(SystemClock);

// 月: 12分周期の conductor。手動 ~tide.() から3分間は待ち、
// 毎tick 6%ずつ目標へ寄るので、返されても潮は跳ばない
~t_moonPeriod = 720;
~t_moonPhase = 0.75;                        // sin=-1 → 大干潮から満ちはじめる
~t_moonTask !? { ~t_moonTask.stop };
~t_moonTask = Task({
    inf.do {
        2.wait;
        if(Main.elapsedTime > ~t_manualUntil) {
            ~t_moonPhase = (~t_moonPhase + (2 / ~t_moonPeriod));
            ~t_moonTarget = ((sin(~t_moonPhase * 2pi) * 0.45) + 0.5);
            ~t_now = (~t_now + ((~t_moonTarget - ~t_now) * 0.06));
            Ndef(\t_tideBus).set(\v, ~t_now);
        };
    };
});

~t_growTask !? { ~t_growTask.stop };
~t_growTask = Task({
    25.wait;
    Ndef(\t_sub, {                          // サブの潮 (26秒周期の呼吸 × 潮位)
        var tide = Ndef.kr(\t_tideBus, 1);
        var breath = SinOsc.kr((1 / 26), 1.5pi).range(0, 1).pow(2);
        var sig = (SinOsc.ar(~t_fund) + (SinOsc.ar((~t_fund * 2)) * 0.12));
        (LPF.ar(sig, 160) * breath * tide.pow(1.2) * 0.26) ! 2
    });

    25.wait;
    Ndef(\t_glint, Pbind(
        \instrument, \t_pip,
        \dur,  Pfunc { ((6.5 - (~t_now * 5.2)).max(0.7) * rrand(0.5, 1.6)) },
        \freq, Pfunc { (~t_fund * (~t_chord.choose * 8)) },
        \dec,  Pwhite(0.9, 2.0),
        \amp,  Pfunc { ((~t_now - 0.2).clip(0, 0.8) * rrand(0.4, 1.0) * 0.08) },
        \pan,  Pwhite(-0.7, 0.7)
    ));

    30.wait;
    ~t_moonTask.play(SystemClock);
}).play(SystemClock);
)


// [3] 潮見表 -------------------------------------------------
// 鳴らしたまま、好きな行を評価すると潮と空間が入れ替わる

// 潮を動かす (これがこの曲の全て)
~tide.(0.03);       // 大干潮 ― 霧と鉦鼓だけの岩場
~tide.(0.25);       // 上げ三分 ― 底が脈打ち、笙の最初の声
~tide.(0.5);        // 半潮 ― 岩場と海のあわい
~tide.(0.8);        // 満ち ― 笙が積み上がり、光が瞬く
~tide.(1.0);        // 大潮 ― 鉦鼓は水没し、倍音の海だけ

~tideAuto.value;             // 月に返す (すぐ自動運転へ)
~t_manualUntil = inf;        // 潮を今の高さで凍らせる (~tide.()でいつでも解凍)
~t_moonPeriod = 240;         // 月を速める (4分でひとめぐり)
Ndef(\t_tideBus).set(\lagT, 40);   // 潮をさらに遅くする (40秒かけて動く)

// 空間: Greyhole (輪郭が溶ける)
(
Ndef(\t_mix)[1] = \filter -> { |in|
    Greyhole.ar(in, \dtime.kr(0.6), 0.3, \size.kr(3.0), 0.7, \fb.kr(0.9))
};
Ndef(\t_mix).xset(\wet1, 0.5);
)

// 空間: テープエコー (0.43秒・減衰しながら繰り返す)
(
Ndef(\t_mix)[1] = \filter -> { |in|
    in + (LPF.ar(CombL.ar(in, 1, \dtime.kr(0.43), \dfb.kr(4)), 3200) * 0.5)
};
Ndef(\t_mix).xset(\wet1, 0.6);
)

// 空間: 深いホールに戻す (初期状態)
(
Ndef(\t_mix)[1] = \filter -> { |in|
    JPverb.ar(in, \t60.kr(8), 0.35, \vsize.kr(3.5), 0.8)
};
Ndef(\t_mix).xset(\wet1, 0.36);
)

// 深夜モード (全体を沈め、ホールを深く)
(
Ndef(\t_mix).xset(\shoAmp, 0.7, \gongAmp, 0.6, \glintAmp, 0.7, \t60, 13);
)

// 和声を今の和音で凍結 / 再開
// ~t_chordTask.stop;
// ~t_chordTask.play;

// Ndef(\t_mix).xset(\fogAmp, 0);      // 霧だけ晴らす
// NdefMixer(s);                       // 全部品をGUIで


// [4] 停止 (20秒かけて引いていく) ----------------------------
(
~t_chordTask !? { ~t_chordTask.stop };
~t_growTask  !? { ~t_growTask.stop };
~t_moonTask  !? { ~t_moonTask.stop };
Ndef(\t_mix).end(20);
)


// [5] 完全掃除 ([4]のフェードが終わってから) ------------------
(
[\t_tideBus, \t_sho, \t_fog, \t_sub, \t_gong, \t_glint, \t_hiss, \t_mix]
    .do { |k| Ndef(k).clear };
)
