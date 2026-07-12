(
~t_outDev = ["BlackHole 2ch"]
    .detect { |d| ServerOptions.outDevices.includesEqual(d) };
if(~t_outDev.notNil) { s.options.outDevice_(~t_outDev) };
s.options.numInputBusChannels_(0);
s.options.numWireBufs_(256);
s.options.memSize_(8192 * 64);

s.waitForBoot({
    ~t_fund = (430 / 8);

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

(
~t_now = 0.12;
Ndef(\t_tideBus, { Lag.kr(\v.kr(0.12), \lagT.kr(10)) });

~t_manualUntil = 0;
~tide = { |x|
    ~t_now = x.clip(0.0, 1.0);
    ~t_manualUntil = (Main.elapsedTime + 180);
    Ndef(\t_tideBus).set(\v, ~t_now);
};
~tideAuto = { ~t_manualUntil = 0; };

~t_sets = [
    [6, 8, 9, 12],
    [4, 6, 7, 9],
    [3, 8, 10, 12],
    [4, 6, 8, 9]
];
~t_idx = 0;
~t_chord = ~t_sets[0];

Ndef(\t_sho).fadeTime = 10;
~t_setSho = {
    var lad = (~t_chord ++ (~t_chord * 2) ++ [(~t_chord[0] * 4)])
        .asSet.asArray.sort;
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

Ndef(\t_hiss, {
    var tide = Ndef.kr(\t_tideBus, 1);
    var wash = SinOsc.kr((1 / 9), Rand(0, 2pi)).range(0, 1).pow(2);
    HPF.ar(BrownNoise.ar(1 ! 2), 6000)
        * LFNoise1.kr(0.05).range(0.15, 1)
        * (0.005 + (wash * tide * 0.01))
});

Ndef(\t_gong).quant = 0;
Ndef(\t_gong, Pbind(
    \instrument, \t_kane,
    \dur,  Pfunc { ((3.0 + (~t_now * 15)) * rrand(0.6, 1.5)) },
    \freq, Pfunc { (~t_fund * [8, 9, 12, 16].choose) },
    \rel,  Pwhite(5.0, 8.0),
    \amp,  Pfunc { (((1 - ~t_now).pow(1.3) * rrand(0.5, 1.0) * 0.3) + 0.008) },
    \pan,  Pwhite(-0.6, 0.6)
));

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

~t_moonPeriod = 720;
~t_moonPhase = 0.75;
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
    Ndef(\t_sub, {
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

~tide.(0.03)
~tide.(0.25);
~tide.(0.5);
~tide.(0.8);
~tide.(1.0);

~tideAuto.value;
~t_manualUntil = inf;
~t_moonPeriod = 240;
Ndef(\t_tideBus).set(\lagT, 40);

(
Ndef(\t_mix)[1] = \filter -> { |in|
    Greyhole.ar(in, \dtime.kr(0.6), 0.3, \size.kr(3.0), 0.7, \fb.kr(0.9))
};
Ndef(\t_mix).set(\wet1, 0.5);
)

(
Ndef(\t_mix)[1] = \filter -> { |in|
    in + (LPF.ar(CombL.ar(in, 1, \dtime.kr(0.43), \dfb.kr(4)), 3200) * 0.5)
};
Ndef(\t_mix).set(\wet1, 0.6);
)

(
Ndef(\t_mix)[1] = \filter -> { |in|
    JPverb.ar(in, \t60.kr(8), 0.35, \vsize.kr(3.5), 0.8)
};
Ndef(\t_mix).set(\wet1, 0.36);
)

(
Ndef(\t_mix).xset(\shoAmp, 0.7, \gongAmp, 0.6, \glintAmp, 0.7);
Ndef(\t_mix).set(\t60, 13);
)

~t_chordTask.stop;
~t_chordTask.play;

Ndef(\t_mix).xset(\fogAmp, 0);
NdefMixer(s);

(
~t_chordTask !? { ~t_chordTask.stop };
~t_growTask  !? { ~t_growTask.stop };
~t_moonTask  !? { ~t_moonTask.stop };
Ndef(\t_mix).end(20);
)

(
[\t_tideBus, \t_sho, \t_fog, \t_sub, \t_gong, \t_glint, \t_hiss, \t_mix]
    .do { |k| Ndef(k).clear };
)
