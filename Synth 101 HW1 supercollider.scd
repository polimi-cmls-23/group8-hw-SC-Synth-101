(
s.boot;
s.latency = 0.01;
)

(
~pedalOrder=[0,1,2]; //we need this to keep track of the order of the pedals, initially phaser=0 , flager=1 , wah wah=2
~b1 = Bus.audio(s);
~b2= Bus.audio(s);
~bout= Bus.audio(s,2);
~boutForFrequencyOutGraph= Bus.audio(s,1);
~firstInputChannel=s.options.numOutputBusChannels;

~bufferA = Buffer.alloc(Server.default, s.sampleRate,2); // allocate two audio buffers
~bufferB = Buffer.alloc(Server.default, s.sampleRate,2);
)

//////////////////////////////////////////////DEFINITIONS OF THE 3 EFFECTS

(
SynthDef(\myphaser, {
	arg depth=0.5, mod_freq=0.6,input_bus, output_bus, bypassp=0;
	var input, output, phased_input;
	var num=4;


	input=In.ar(input_bus); //read from input bus


	phased_input=input;
	while({num>0},{
		phased_input = AllpassC.ar(phased_input, 0.2, SinOsc.kr(mod_freq, 0, 0.0015,0.005), 0);num=num-1});


	output=Select.ar(bypassp,[2*Mix.ar([input*(1-depth),phased_input*depth]),input]); //do you want to bypass this pedal?

	Out.ar(output_bus,output); //write on output bus

}).add;




SynthDef(\flanger, {

	arg ampLFO = 0.0025, freqLFO = 1.5, input_bus, output_bus, bypassf=0, gff=0.5, gfb=0.5;
	var maxdelay=0.01;

	var signal_x,signal_x_delayed,signal_xCycle2, output;
	var myLFO, maxdepth, basedelay;


	signal_x=In.ar(input_bus);//read from input bus
	basedelay=maxdelay/2;
	myLFO = SinOsc.kr(freqLFO,mul:ampLFO);


	signal_x_delayed = DelayC.ar(signal_x, maxdelay,basedelay+ myLFO);
	signal_xCycle2 = Mix.ar([signal_x*(1-gfb), signal_x_delayed*(gfb)]);
	signal_x_delayed = DelayC.ar(signal_xCycle2, maxdelay,basedelay+ myLFO);

	output=Select.ar(bypassf,[2*Mix.ar([signal_x_delayed*gff,signal_x*(1-gff)]),signal_x]);//do you want to bypass this pedal?

	Out.ar(output_bus,output); //write on output bus

}).add;







SynthDef(\wahWah,{
	arg dur = 1.25, amount = 0.5,input_bus, output_bus, bypassw=0;
	var bpf, e, lpf, input, output, mix, fw = 350; //fw => wah frequency





	input=In.ar(input_bus); //read from input bus

	e = Env([1,6.28,1], [dur/2,dur/2]);
	bpf = BPF.ar(input, fw*EnvGen.kr(e,SinOsc.kr(1/dur)));
	mix = Mix.ar([(1-amount)*input,amount*bpf]);



	output=Select.ar(bypassw,[2*mix,input]); //do you want to bypass this pedal?


	Out.ar(output_bus, output); //write on output bus

}).add;




SynthDef(\outputAudioStereo,{
	//send audio to the speakers (we use this after the chain of effects)
	arg master = 1, playSilence=1, pan=0.5;
	var output=Select.ar(playSilence,[master*In.ar(~bout),Silent.ar(1)]);

	Out.ar(0, output*(1-pan));
	Out.ar(1, output*pan);


	~bufferA = Buffer.alloc(Server.default, s.sampleRate,2); // allocate two audio buffers
	~bufferB = Buffer.alloc(Server.default, s.sampleRate,2);

	ScopeOut2.ar(In.ar(~firstInputChannel), ~bufferA); // use ScopeOut2!
	ScopeOut2.ar(In.ar([0,1]), ~bufferB); // use ScopeOut2


	Out.ar(~boutForFrequencyOutGraph, output);
}).add;

)









//////////////////////////////////////////////GUI AND BUS IMPLEMENTATION





(
var view1, view2, view3, view4, view5; //Pedal interfaces
var leftSwitchButton, rightSwitchButton; //buttons that switch the order of the pedals

var phaserLabel, flangerLabel, wahwahLabel; //labels on the top of the pedals
var durwahLabel, amountwahLabel, panLabel; //labels of the knobs of the pedals
var specFreqp,specDepthp,specAmpf,specFreqf,specGfb,specGff,specDurw,specAmountw,specMaster,specPan; //to help us define the limit values of the knobs
var knobPan;
var pSynth, fSynth, wSynth, outputAudioStereoSynth; //we'll use these to get the audio of the Synthesizers

var durwah, amountwah;
var freqf, ampf, regenf, wetf;
var freqp, depthp;


var scopein, scopeout;
var insign, outsign;

//Colors
var myLightGrey=Color.new255(220,220,220);
var myDarkGrey=Color.new255(160,160,160);
var myColor1=Color.fromHexString("#FF7519");
var myColor2=Color.fromHexString("#E0D2C8");
var myColor3=Color.fromHexString("#F5961B");
var myColor4=Color.fromHexString("#E3DACA");
var myColor5=Color.fromHexString("#F5BA19");



var pedalLeft=10, pedalTop=20, pedalWidth=162, pedalHeight=378, pedalDistance=260;
var scopeLeft=10, scopeTop=423, scopeWidth=500, scopeHeight=189, scopeDistance=471;
var pedalScopeDistance=360;
var rectLabel=Rect(0, 0, pedalWidth*2, 40);
var case; //case will help later in distinguishing the order of the pedals
var firstInputChannel=s.options.numOutputBusChannels;

//second arrow variables
var arrScale1 = 0.2;
var arrWidth1 = (2*(pedalWidth + pedalLeft)) + 425, arrheight1 = (pedalHeight/2) + (pedalTop/4);

//first arrow variables
var arrScale = 0.2;
var arrWidth = (pedalWidth + pedalLeft) + 175, arrheight = (pedalHeight/2) + 5;



//Order in which the pedals should initially play:
~phaserGroup=Group.new; //phaser=0
~flangerGroup=Group.after(~phaserGroup); //flanger=1
~wahGroup=Group.after(~flangerGroup); //wahwah=2
~outputAudioStereoGroup=Group.after(~wahGroup);
~pedalOrder=[0,1,2]; //we need this to keep track of the order of the pedals




w = Window("Multieffect", Rect(20, 90, 20 + (pedalDistance*2)+(pedalWidth*4),(scopeTop+scopeHeight+1)-(pedalTop-10)+20), false).front;//window non resizable


w.background_(Color.blue);

w.drawFunc = {


	//Pen.fillRect(Rect(0, 0, 1330, 640)); //external black borders OK!
	//Pen.fillColor = myLightGrey;
	//Pen.fillRect(Rect(5, 5, 1320, 630)); //external light grey surface


	Pen.fillColor = myColor2;
	Pen.fillRect(Rect(pedalLeft-10, 0, 20 + (pedalDistance*2)+(pedalWidth*4),(scopeTop+scopeHeight+1)-(pedalTop-10)+20)); //pedalboard surface


	Pen.width_(5);
	Pen.strokeColor=myDarkGrey;
	Pen.strokeRect(Rect(pedalLeft-10, 1, 20 + (pedalDistance*2)+(pedalWidth*4),(scopeTop+scopeHeight+1)-(pedalTop-10)+19)); //pedalboard borders


	Pen.fillColor = myDarkGrey;
	Pen.fillRect(Rect(scopeLeft-1, scopeTop-1, scopeWidth+2, scopeHeight+2));//scope borders
	Pen.fillRect(Rect(pedalLeft+ (pedalWidth*4) +(pedalDistance*2)-scopeWidth-1, scopeTop-1, scopeWidth+2, scopeHeight+2));

	Pen.fillColor = Color.grey(0.2);
	Pen.fillRect(Rect(pedalLeft-1, pedalTop-1, (pedalWidth*2)+2, pedalHeight+2)); //pedals borders
	Pen.fillRect(Rect(pedalLeft+pedalDistance+pedalWidth-1, pedalTop-1, pedalWidth*2+2, pedalHeight+2));
	Pen.fillRect(Rect((pedalDistance*2)+(pedalWidth*2)+pedalLeft-1,  pedalTop-1, (pedalWidth*2)+2, pedalHeight+2));

	//Pen.fillRect(Rect(pedalLeft+(pedalDistance/2)+(pedalWidth*1.5)-41, pedalTop+(pedalHeight/2)-41, 82, 82)); //switch button borders
	//Pen.fillRect(Rect(pedalLeft+(pedalDistance*1.5)+(pedalWidth*2.5)-41, pedalTop+(pedalHeight/2)-41, 82, 82));


	/*Pen.line(Point(266,pedalTop-2.5), Point(454,pedalTop-2.5));
	Pen.line(Point(626,pedalTop-2.5), Point(814,pedalTop-2.5));
	Pen.line(Point(266,403-9.5), Point(454,403-9.5));
	Pen.line(Point(626,403-9.5), Point(814,403-9.5));*/

	Pen.fillStroke;

	//Arrows
	Pen.fillColor_(Color.black);
	Pen.strokeColor_(Color.gray);
	Pen.width_(arrScale*2);
	Pen.moveTo(((arrScale*108)+arrWidth)@((arrScale*50)+arrheight));
	Pen.lineTo(((arrScale*108)+arrWidth)@(arrheight));
	Pen.lineTo((arrWidth)@((arrScale*75)+arrheight));
	Pen.lineTo(((arrScale*108)+arrWidth)@((arrScale*150)+arrheight));
	Pen.lineTo(((arrScale*108)+arrWidth)@((arrScale*100)+arrheight));
	Pen.lineTo(((arrScale*241)+arrWidth)@((arrScale*100)+arrheight));
	Pen.lineTo(((arrScale*241)+arrWidth)@((arrScale*150)+arrheight));
	Pen.lineTo(((arrScale*350)+arrWidth)@((arrScale*75)+arrheight));
	Pen.lineTo(((arrScale*241)+arrWidth)@(arrheight));
	Pen.lineTo(((arrScale*241)+arrWidth)@((arrScale*50)+arrheight));
	Pen.lineTo(((arrScale*108)+arrWidth)@((arrScale*50)+arrheight));
	Pen.fill;

    Pen.moveTo(((arrScale*108)+arrWidth)@((arrScale*50)+arrheight));
	Pen.lineTo(((arrScale*108)+arrWidth)@(arrheight));
	Pen.lineTo((arrWidth)@((arrScale*75)+arrheight));
	Pen.lineTo(((arrScale*108)+arrWidth)@((arrScale*150)+arrheight));
	Pen.lineTo(((arrScale*108)+arrWidth)@((arrScale*100)+arrheight));
	Pen.lineTo(((arrScale*241)+arrWidth)@((arrScale*100)+arrheight));
	Pen.lineTo(((arrScale*241)+arrWidth)@((arrScale*150)+arrheight));
	Pen.lineTo(((arrScale*350)+arrWidth)@((arrScale*75)+arrheight));
	Pen.lineTo(((arrScale*241)+arrWidth)@(arrheight));
	Pen.lineTo(((arrScale*241)+arrWidth)@((arrScale*50)+arrheight));
	Pen.lineTo(((arrScale*108)+arrWidth)@((arrScale*50)+arrheight));
	Pen.stroke;

	Pen.width_(arrScale*2);
	Pen.moveTo(((arrScale1*108)+arrWidth1)@((arrScale1*50)+arrheight1));
	Pen.lineTo(((arrScale1*108)+arrWidth1)@(arrheight1));
	Pen.lineTo((arrWidth1)@((arrScale1*75)+arrheight1));
	Pen.lineTo(((arrScale1*108)+arrWidth1)@((arrScale1*150)+arrheight1));
	Pen.lineTo(((arrScale1*108)+arrWidth1)@((arrScale1*100)+arrheight1));
	Pen.lineTo(((arrScale1*241)+arrWidth1)@((arrScale1*100)+arrheight1));
	Pen.lineTo(((arrScale1*241)+arrWidth1)@((arrScale1*150)+arrheight1));
	Pen.lineTo(((arrScale1*350)+arrWidth1)@((arrScale1*75)+arrheight1));
	Pen.lineTo(((arrScale1*241)+arrWidth1)@(arrheight1));
	Pen.lineTo(((arrScale1*241)+arrWidth1)@((arrScale1*50)+arrheight1));
	Pen.lineTo(((arrScale1*108)+arrWidth1)@((arrScale1*50)+arrheight1));
	Pen.fill;

  	Pen.width_(arrScale*2);
	Pen.moveTo(((arrScale1*108)+arrWidth1)@((arrScale1*50)+arrheight1));
	Pen.lineTo(((arrScale1*108)+arrWidth1)@(arrheight1));
	Pen.lineTo((arrWidth1)@((arrScale1*75)+arrheight1));
	Pen.lineTo(((arrScale1*108)+arrWidth1)@((arrScale1*150)+arrheight1));
	Pen.lineTo(((arrScale1*108)+arrWidth1)@((arrScale1*100)+arrheight1));
	Pen.lineTo(((arrScale1*241)+arrWidth1)@((arrScale1*100)+arrheight1));
	Pen.lineTo(((arrScale1*241)+arrWidth1)@((arrScale1*150)+arrheight1));
	Pen.lineTo(((arrScale1*350)+arrWidth1)@((arrScale1*75)+arrheight1));
	Pen.lineTo(((arrScale1*241)+arrWidth1)@(arrheight1));
	Pen.lineTo(((arrScale1*241)+arrWidth1)@((arrScale1*50)+arrheight1));
	Pen.lineTo(((arrScale1*108)+arrWidth1)@((arrScale1*50)+arrheight1));

	Pen.stroke;



};

//Arrow view
q = View.new(w,Rect((arrScale*0) + arrWidth,(arrScale*0) + arrheight,arrScale*350,arrScale*150));
u = View.new(w,Rect((arrScale1*0) + arrWidth1,(arrScale1*0) + arrheight1,arrScale1*350,arrScale1*150));



//Basic pedals interfaces
view1 = CompositeView(w, Rect(pedalLeft, pedalTop, (pedalWidth*2), pedalHeight));
view1.background = myColor1;
phaserLabel = StaticText(view1, rectLabel);
phaserLabel.background = myColor1;
phaserLabel.string_("PHASER");
phaserLabel.font = Font("Monaco", 25);
phaserLabel.align_(\center);

view2= CompositeView(w, Rect(pedalLeft+pedalDistance+pedalWidth, pedalTop, 2*pedalWidth, pedalHeight));
view2.background=myColor3;
flangerLabel = StaticText(view2, rectLabel);
flangerLabel.background = myColor3;
flangerLabel.string_("FLANGER");
flangerLabel.font = Font("Monaco", 25);
flangerLabel.align_(\center);

view3=CompositeView(w, Rect(pedalDistance*2+(pedalWidth*2)+pedalLeft, pedalTop, (pedalWidth*2), pedalHeight));
view3.background=myColor5;
wahwahLabel = StaticText(view3, rectLabel);
wahwahLabel.background = myColor5;
wahwahLabel.string_("WAH-WAH");
wahwahLabel.font = Font("Monaco", 25);
wahwahLabel.align_(\center);

//NOMI KNOBS


//PHASER
freqp = StaticText(view1, Rect(85,155,70,40));
freqp.background = myColor1;
freqp.string_("frequency");
freqp.stringColor_(Color.black);
freqp.font = Font("Verdana Pro Light", 16);
freqp.align_(\center);

depthp = StaticText(view1, Rect(9+pedalWidth,295,70,40));
depthp.background = myColor1;
depthp.string_("dry/wet");
depthp.stringColor_(Color.black);
depthp.font = Font("Verdana Pro Light", 16);
depthp.align_(\center);


//FLANGER
freqf = StaticText(view2, Rect(85,155,70,40));
freqf.background = myColor3;
freqf.string_("frequency");
freqf.stringColor_(Color.black);
freqf.font = Font("Verdana Pro Light", 16);
freqf.align_(\center);

ampf = StaticText(view2, Rect(9,295,70,40));
ampf.background = myColor3;
ampf.string_("width");
ampf.stringColor_(Color.black);
ampf.font = Font("Verdana Pro Light", 16);
ampf.align_(\center);

regenf = StaticText(view2, Rect(85+pedalWidth,155,70,40));
regenf.background = myColor3;
regenf.string_("feedback");
regenf.stringColor_(Color.black);
regenf.font = Font("Verdana Pro Light", 16);
regenf.align_(\center);

wetf = StaticText(view2, Rect(9+pedalWidth,295,70,40));
wetf.background = myColor3;
wetf.string_("dry/wet");
wetf.stringColor_(Color.black);
wetf.font = Font("Verdana Pro Light", 16);
wetf.align_(\center);


//WAHWAH
durwah = StaticText(view3, Rect(85,155,70,40));
durwah.background = myColor5;
durwah.string_("frequency");
durwah.stringColor_(Color.black);
durwah.font = Font("Verdana Pro Light", 16);
durwah.align_(\center);

amountwah = StaticText(view3, Rect(9+pedalWidth,295,70,40));
amountwah.background = myColor5;
amountwah.string_("dry/wet");
amountwah.stringColor_(Color.black);
amountwah.font = Font("Verdana Pro Light", 16);
amountwah.align_(\center);





//synth definition
pSynth = Synth(\myphaser,[\input_bus, firstInputChannel, \output_bus,~b1],target:~phaserGroup);


fSynth = Synth(\flanger,[\input_bus, ~b1, \output_bus,~b2,],target:~flangerGroup);


wSynth = Synth(\wahWah,[\input_bus, ~b2, \output_bus,~bout.index,],target:~wahGroup);


outputAudioStereoSynth= Synth(\outputAudioStereo,[\master, 1, \playSilence, 0, \pan, 0.5],target:~outputAudioStereoGroup);

//////////////////////////////////////////////PHASER

//knobs
specFreqp=ControlSpec.new(0.2,1,\lin);
~knobFreqp=EZKnob.new(view1,Rect(15,110,65,70),nil,specFreqp,initVal:0.6,labelWidth:0, labelHeight:0);
~knobFreqp.action_({arg me;	pSynth.set(\mod_freq, me.value);
});

specDepthp=ControlSpec.new(0,1,\lin);
~knobDepthp=EZKnob.new(view1,Rect(82+pedalWidth,250,65,70),nil,specDepthp,initVal:0.5,labelWidth:0, labelHeight:0);
~knobDepthp.action_({arg me; pSynth.set(\depth, me.value)});


// ON-OFF button
~buttonp= Button(view1,Rect(pedalWidth-25,340,50,30)).states_([
	["ON",Color.grey(0.9),Color.new255(19,195,90)],
	["OFF",Color.grey(0.9),Color.new255(203,43,43)]

]).font_(Font("Monaco",18)).action_({

	pSynth.set(\bypassp,~buttonp.value);

});



//////////////////////////////////////////////FLANGER


//knobs

specFreqf = ControlSpec.new(0, 3, \lin);
~knobFreqf = EZKnob.new(view2, Rect(15,110,65,70), nil, controlSpec:specFreqf, initVal:1.5,labelWidth:0, labelHeight:0);//FREQ
~knobFreqf.action_({arg me; fSynth.set(\freqLFO, me.value) });


specAmpf = ControlSpec.new(0, 0.005, \lin);
~knobAmpf = EZKnob.new(view2, Rect(82,250,65,70), nil, controlSpec:specAmpf, initVal:0.0025,labelWidth:0, labelHeight:0);//AMP
~knobAmpf.action_({arg me; fSynth.set(\ampLFO, me.value) });


specGfb = ControlSpec.new(0, 1, \lin);
~knobGfb = EZKnob.new(view2, Rect(15+pedalWidth,110,65,70), nil, controlSpec:specGfb, initVal:0.5,labelWidth:0, labelHeight:0);//FREQ
~knobGfb.action_({arg me; fSynth.set(\gfb, me.value) });

specGff = ControlSpec.new(0, 1, \lin);
~knobGff = EZKnob.new(view2, Rect(82+pedalWidth,250,65,70), nil, controlSpec:specGff, initVal:0.5,labelWidth:0, labelHeight:0);//FREQ
~knobGff.action_({arg me; fSynth.set(\gff, me.value) });



// ON-OFF button
~buttonf= Button(view2,Rect(pedalWidth-25,340,50,30)).states_([
	["ON",Color.grey(0.9),Color.new255(19,195,90)],
	["OFF",Color.grey(0.9),Color.new255(203,43,43)]
]).font_(Font("Monaco",18)).action_({

	fSynth.set(\bypassf,~buttonf.value);

});










//////////////////////////////////////////////WAH WAH


//knobs
specDurw = ControlSpec.new(2.0,0.5, 'lin');
~knobDurw = EZKnob.new(view3, Rect(15,110,65,70),nil,specDurw,initVal:1.25, labelWidth:0, labelHeight:0);//dur
~knobDurw.action_({arg me; wSynth.set(\dur, me.value)});


specAmountw = ControlSpec.new(0, 1, 'lin');
~knobAmountw = EZKnob.new(view3, Rect(82+pedalWidth,250,65,70),nil,specAmountw, initVal:0.5, labelWidth:0, labelHeight:0);//amount
~knobAmountw.action_({arg me; wSynth.set(\amount, me.value)});


// ON-OFF button
~buttonw= Button(view3,Rect(pedalWidth-25,340,50,30)).states_([
	["ON",Color.grey(0.9),Color.new255(19,195,90)],
	["OFF",Color.grey(0.9),Color.new255(203,43,43)]
]).font_(Font("Monaco",18)).action_({

	wSynth.set(\bypassw,~buttonw.value);

});



//////////////////////////////////////////////MASTER GUI
specMaster=ControlSpec.new(0,1,\lin);
~knobMaster=EZKnob.new(w,Rect(pedalLeft+ (pedalWidth*4) +(pedalDistance*2)-scopeWidth-68, scopeTop, 65, 70),nil,specMaster,initVal:1,labelWidth:0, labelHeight:0);
~knobMaster.action_({arg me;outputAudioStereoSynth.set(\master, me.value);
});

specPan=ControlSpec.new(0,1,\lin,0.1);
knobPan=EZKnob.new(w,Rect(scopeLeft+scopeWidth+3, scopeTop, 65, 70),nil,specPan,initVal:0.5,labelWidth:0, labelHeight:0);
knobPan.action_({arg me;outputAudioStereoSynth.set(\pan, me.value);
});

// ON-OFF button
~buttonMaster= Button(w,Rect(scopeLeft+scopeWidth+3, scopeTop+scopeHeight-40, (pedalLeft+ (pedalWidth*4) +(pedalDistance*2)-scopeWidth)-(scopeLeft+scopeWidth+6), 40)).states_([
	["ON",Color.grey(0.9),Color.new255(19,195,90)],
	["OFF",Color.grey(0.9),Color.new255(203,43,43)]

]).font_(Font("Monaco",18)).action_({

	outputAudioStereoSynth.free;
	outputAudioStereoSynth=Synth (\outputAudioStereo,[\playSilence,~buttonMaster.value],~outputAudioStereoGroup);
});



panLabel = StaticText(w, Rect(scopeLeft+scopeWidth+3, scopeTop+67, 65, 20));
panLabel.background = myColor2;
panLabel.string_("Pan");
panLabel.font = Font("Verdana Pro Light", 16);
panLabel.align_(\center);


panLabel = StaticText(w, Rect(pedalLeft+ (pedalWidth*4) +(pedalDistance*2)-scopeWidth-68, scopeTop+67, 65, 20));
panLabel.background = myColor2;
panLabel.string_("Master");
panLabel.font = Font("Verdana Pro Light", 16);
panLabel.align_(\center);


//////////////////////////////////////////////TRANSLATION OF THE GUI









//LEFT SWITCH IMPLEMENTATION (of both GUI and audio)

//leftSwitchButton = Button(w, Rect(pedalLeft+(pedalDistance/2)+(pedalWidth*1.5)-40, pedalTop+(pedalHeight/2)-40, 80, 80));

//leftSwitchButton.states = [["SWITCH"]];

q.mouseDownAction = { // WE USE THE ~pedalOrder ARRAY TO AKNOWLEDGE THE POSITIONS OF THE FIRST TWO PEDALS
	if((~pedalOrder[0]==0).and(~pedalOrder[1]==1),{case=0},{});//phaser and flanger
	if((~pedalOrder[0]==1).and(~pedalOrder[1]==0),{case=1},{});//flanger and phaser

	if((~pedalOrder[0]==0).and(~pedalOrder[1]==2),{case=2},{});//phaser and wah wah
	if((~pedalOrder[0]==2).and(~pedalOrder[1]==0),{case=3},{});//wah wah and phaser

	if((~pedalOrder[0]==1).and(~pedalOrder[1]==2),{case=4},{});//flanger and wah wah
	if((~pedalOrder[0]==2).and(~pedalOrder[1]==1),{case=5},{});//wah wah and flanger


	~pedalOrder.swap(0, 1); //we update the pedals order

	//phaser and flanger switch, the new configuration becomes FPW
	if (case==0,{
		view2.moveTo(pedalLeft, pedalTop);
		view1.moveTo(pedalLeft+pedalDistance+(pedalWidth), pedalTop);
		//recreating the correct groups configuration
		~phaserGroup.free;
		~flangerGroup.free;
		~wahGroup.free;
		~outputAudioStereoGroup.free;
		~flangerGroup=Group.new;//1
		~phaserGroup=Group.after(~flangerGroup); //0
		~wahGroup=Group.after(~phaserGroup); //2
		~outputAudioStereoGroup=Group.after(~wahGroup);

		//recreating the correct synths, while keeping the old button and knobs values
		fSynth = Synth(\flanger,
			[\input_bus, firstInputChannel, \output_bus,~b1,\freqLFO,~knobFreqf.value,\ampLFO,~knobAmpf.value,\gfb,~knobGfb.value,\gff,~knobGff.value,\bypassf,~buttonf.value]
			,target:~flangerGroup);
		pSynth = Synth(\myphaser,
			[\input_bus, ~b1, \output_bus,~b2,\mod_freq,~knobFreqp.value,\depth,~knobDepthp.value,\bypassp,~buttonp.value]
			,target:~phaserGroup);
		wSynth = Synth(\wahWah,
			[\input_bus, ~b2, \output_bus,~bout,\dur,~knobDurw.value,\amount,~knobAmountw.value,\bypassw,~buttonw.value],
			target:~wahGroup);
		outputAudioStereoSynth= Synth(\outputAudioStereo,[\master, ~knobMaster.value, \playSilence, ~buttonMaster.value, \pan, knobPan.value],target:~outputAudioStereoGroup);
	},{});

	//flanger and phaser switch, the new configuration becomes PFW
	if (case==1,{
		view1.moveTo(pedalLeft, pedalTop);
		view2.moveTo(pedalLeft+pedalDistance+pedalWidth, pedalTop);
		~phaserGroup.free;
		~flangerGroup.free;
		~wahGroup.free;
		~outputAudioStereoGroup.free;
		~phaserGroup=Group.new;//0
		~flangerGroup=Group.after(~phaserGroup); //1
		~wahGroup=Group.after(~flangerGroup); //2
		~outputAudioStereoGroup=Group.after(~wahGroup);




		pSynth = Synth(\myphaser,
			[\input_bus, firstInputChannel, \output_bus,~b1,\mod_freq,~knobFreqp.value,\depth,~knobDepthp.value,\bypassp,~buttonp.value]
			,target:~phaserGroup);
		fSynth = Synth(\flanger,
			[\input_bus, ~b1, \output_bus,~b2,\freqLFO,~knobFreqf.value,\ampLFO,~knobAmpf.value,\gfb,~knobGfb.value,\gff,~knobGff.value,\bypassf,~buttonf.value]
			,target:~flangerGroup);
		wSynth = Synth(\wahWah,
			[\input_bus, ~b2, \output_bus,~bout,\dur,~knobDurw.value,\amount,~knobAmountw.value,\bypassw,~buttonw.value]
			,target:~wahGroup);
		outputAudioStereoSynth= Synth(\outputAudioStereo,[\master, ~knobMaster.value, \playSilence, ~buttonMaster.value, \pan, knobPan.value],target:~outputAudioStereoGroup);

	},{});

	//phaser and wah wah switch, the new configuration becomes WPF
	if (case==2,{
		view3.moveTo(pedalLeft, pedalTop);
		view1.moveTo(pedalLeft+pedalDistance+(pedalWidth), pedalTop);

		~phaserGroup.free;
		~flangerGroup.free;
		~wahGroup.free;
		~outputAudioStereoGroup.free;
		~wahGroup=Group.new;//2
		~phaserGroup=Group.after(~wahGroup); //0
		~flangerGroup=Group.after(~phaserGroup); //1
		~outputAudioStereoGroup=Group.after(~flangerGroup);

		wSynth = Synth(\wahWah,
			[\input_bus, firstInputChannel, \output_bus,~b1,\dur,~knobDurw.value,\amount,~knobAmountw.value,\bypassw,~buttonw.value]
			,target:~wahGroup);
		pSynth = Synth(\myphaser,
			[\input_bus, ~b1, \output_bus,~b2,\mod_freq,~knobFreqp.value,\depth,~knobDepthp.value,\bypassp,~buttonp.value]
			,target:~phaserGroup);
		fSynth = Synth(\flanger,
			[\input_bus, ~b2, \output_bus,~bout,\freqLFO,~knobFreqf.value,\ampLFO,~knobAmpf.value,\gfb,~knobGfb.value,\gff,~knobGff.value,\bypassf,~buttonf.value]
			,target:~flangerGroup);
		outputAudioStereoSynth= Synth(\outputAudioStereo,[\master, ~knobMaster.value, \playSilence, ~buttonMaster.value, \pan, knobPan.value],target:~outputAudioStereoGroup);

	},{});
	//wah wah and phaser switch, the new configuration becomes PWF
	if (case==3,{
		view1.moveTo(pedalLeft, pedalTop);
		view3.moveTo(pedalLeft+pedalDistance+pedalWidth, pedalTop);

		~phaserGroup.free;
		~flangerGroup.free;
		~wahGroup.free;
		~outputAudioStereoGroup.free;
		~phaserGroup=Group.new;
		~wahGroup=Group.after(~phaserGroup);
		~flangerGroup=Group.after(~wahGroup);
		~outputAudioStereoGroup=Group.after(~flangerGroup);

		pSynth = Synth(\myphaser,
			[\input_bus, firstInputChannel, \output_bus,~b1,\mod_freq,~knobFreqp.value,\depth,~knobDepthp.value,\bypassp,~buttonp.value]
			,target:~phaserGroup);
		wSynth = Synth(\wahWah,
			[\input_bus, ~b1, \output_bus,~b2,\dur,~knobDurw.value,\amount,~knobAmountw.value,\bypassw,~buttonw.value]
			,target:~wahGroup);
		fSynth = Synth(\flanger,
			[\input_bus, ~b2, \output_bus,~bout,\freqLFO,~knobFreqf.value,\ampLFO,~knobAmpf.value,\gfb,~knobGfb.value,\gff,~knobGff.value,\bypassf,~buttonf.value]
			,target:~flangerGroup);
		outputAudioStereoSynth= Synth(\outputAudioStereo,[\master, ~knobMaster.value, \playSilence, ~buttonMaster.value, \pan, knobPan.value],target:~outputAudioStereoGroup);

	},{});

	//flanger and wah wah switch, the new configuration becomes WFP
	if (case==4,{
		view3.moveTo(pedalLeft, pedalTop);
		view2.moveTo(pedalLeft+pedalDistance+pedalWidth, pedalTop);


		~phaserGroup.free;
		~flangerGroup.free;
		~wahGroup.free;
		~outputAudioStereoGroup.free;
		~wahGroup=Group.new;
		~flangerGroup=Group.after(~wahGroup);
		~phaserGroup=Group.after(~flangerGroup);
		~outputAudioStereoGroup=Group.after(~phaserGroup);

		wSynth = Synth(\wahWah,
			[\input_bus, firstInputChannel, \output_bus,~b1,\dur,~knobDurw.value,\amount,~knobAmountw.value,\bypassw,~buttonw.value]
			,target:~wahGroup);
		fSynth = Synth(\flanger,
			[\input_bus, ~b1, \output_bus,~b2,\freqLFO,~knobFreqf.value,\ampLFO,~knobAmpf.value,\gfb,~knobGfb.value,\gff,~knobGff.value,\bypassf,~buttonf.value]
			,target:~flangerGroup);
		pSynth = Synth(\myphaser,
			[\input_bus, ~b2, \output_bus,~bout,\mod_freq,~knobFreqp.value,\depth,~knobDepthp.value,\bypassp,~buttonp.value]
			,target:~phaserGroup);
		outputAudioStereoSynth= Synth(\outputAudioStereo,[\master, ~knobMaster.value, \playSilence, ~buttonMaster.value, \pan, knobPan.value],target:~outputAudioStereoGroup);
	},{});

	//wah wah and flanger switch, the new configuration becomes FWP
	if (case==5,{
		view2.moveTo(pedalLeft, pedalTop);
		view3.moveTo(pedalLeft+pedalDistance+pedalWidth, pedalTop);

		~phaserGroup.free;
		~flangerGroup.free;
		~wahGroup.free;
		~outputAudioStereoGroup.free;
		~flangerGroup=Group.new;
		~wahGroup=Group.after(~flangerhGroup);
		~phaserGroup=Group.after(~wahGroup);
		~outputAudioStereoGroup=Group.after(~phaserGroup);

		fSynth = Synth(\flanger,
			[\input_bus, firstInputChannel, \output_bus,~b1,\freqLFO,~knobFreqf.value,\ampLFO,~knobAmpf.value,\gfb,~knobGfb.value,\gff,~knobGff.value,\bypassf,~buttonf.value]
			,target:~flangerGroup);
		wSynth = Synth(\wahWah,
			[\input_bus, ~b1, \output_bus,~b2,\dur,~knobDurw.value,\amount,~knobAmountw.value,\bypassw,~buttonw.value]
			,target:~wahGroup);
		pSynth = Synth(\myphaser,
			[\input_bus, ~b2, \output_bus,~bout,\mod_freq,~knobFreqp.value,\depth,~knobDepthp.value,\bypassp,~buttonp.value]
			,target:~phaserGroup);
		outputAudioStereoSynth= Synth(\outputAudioStereo,[\master, ~knobMaster.value, \playSilence, ~buttonMaster.value, \pan, knobPan.value],target:~outputAudioStereoGroup);
	},{});

};








//RIGHT SWITCH IMPLEMENTATION (of both GUI and audio)
//The logic behind this is the same as the one of previous button


//rightSwitchButton = Button(w, Rect(pedalLeft+(pedalDistance*1.5)+(pedalWidth*2.5)-40, pedalTop+(pedalHeight/2)-40, 80, 80));

//rightSwitchButton.states = [["SWITCH"]];



u.mouseDownAction = {

	if((~pedalOrder[1]==0).and(~pedalOrder[2]==1),{case=0},{});//phaser and flanger
	if((~pedalOrder[1]==1).and(~pedalOrder[2]==0),{case=1},{});//flanger and phaser

	if((~pedalOrder[1]==0).and(~pedalOrder[2]==2),{case=2},{});//phaser and wah wah
	if((~pedalOrder[1]==2).and(~pedalOrder[2]==0),{case=3},{});//wah wah and phaser

	if((~pedalOrder[1]==1).and(~pedalOrder[2]==2),{case=4},{});//flanger and wah wah
	if((~pedalOrder[1]==2).and(~pedalOrder[2]==1),{case=5},{});//wah wah and flanger


	~pedalOrder.swap(1, 2);
	~pedalOrder;
	//phaser and flanger switch, the new configuration becomes WFP
	if (case==0,{
		view2.moveTo(pedalLeft+pedalDistance+pedalWidth, pedalTop);
		view1.moveTo((pedalDistance*2)+(pedalWidth*2)+pedalLeft, pedalTop);

		~phaserGroup.free;
		~flangerGroup.free;
		~wahGroup.free;
		~outputAudioStereoGroup.free;
		~wahGroup=Group.new;//2
		~flangerGroup=Group.after(~wahGroup); //1
		~phaserGroup=Group.after(~flangerGroup); //0
		~outputAudioStereoGroup=Group.after(~phaserGroup);

		wSynth = Synth(\wahWah,
			[\input_bus, firstInputChannel, \output_bus,~b1,\dur,~knobDurw.value,\amount,~knobAmountw.value,\bypassw,~buttonw.value]
			,target:~wahGroup);
		fSynth = Synth(\flanger,
			[\input_bus, ~b1, \output_bus,~b2,\freqLFO,~knobFreqf.value,\ampLFO,~knobAmpf.value,\gfb,~knobGfb.value,\gff,~knobGff.value,\bypassf,~buttonf.value]
			,target:~flangerGroup);
		pSynth = Synth(\myphaser,
			[\input_bus, ~b2, \output_bus,~bout,\mod_freq,~knobFreqp.value,\depth,~knobDepthp.value,\bypassp,~buttonp.value]
			,target:~phaserGroup);
		outputAudioStereoSynth= Synth(\outputAudioStereo,[\master, ~knobMaster.value, \playSilence, ~buttonMaster.value, \pan, knobPan.value],target:~outputAudioStereoGroup);
	},{});
	//flanger and phaser switch, the new configuration becomes WPF
	if (case==1,{
		view1.moveTo(pedalLeft+pedalDistance+(pedalWidth), pedalTop);
		view2.moveTo((pedalDistance*2)+(pedalWidth*2)+pedalLeft, pedalTop);

		~phaserGroup.free;
		~flangerGroup.free;
		~wahGroup.free;
		~outputAudioStereoGroup.free;
		~wahGroup=Group.new;//2
		~phaserGroup=Group.after(~wahGroup); //0
		~flangerGroup=Group.after(~phaserGroup); //1
		~outputAudioStereoGroup=Group.after(~flangerGroup);

		wSynth = Synth(\wahWah,
			[\input_bus, firstInputChannel, \output_bus,~b1,\dur,~knobDurw.value,\amount,~knobAmountw.value,\bypassw,~buttonw.value]
			,target:~wahGroup);
		pSynth = Synth(\myphaser,
			[\input_bus, ~b1, \output_bus,~b2,\mod_freq,~knobFreqp.value,\depth,~knobDepthp.value,\bypassp,~buttonp.value]
			,target:~phaserGroup);
		fSynth = Synth(\flanger,
			[\input_bus, ~b2, \output_bus,~bout,\freqLFO,~knobFreqf.value,\ampLFO,~knobAmpf.value,\gfb,~knobGfb.value,\gff,~knobGff.value,\bypassf,~buttonf.value]
			,target:~flangerGroup);
		outputAudioStereoSynth= Synth(\outputAudioStereo,[\master, ~knobMaster.value, \playSilence, ~buttonMaster.value, \pan, knobPan.value],target:~outputAudioStereoGroup);
	},{});

	//phaser and wah wah switch, the new configuration becomes FWP
	if (case==2,{
		view3.moveTo(pedalLeft+pedalDistance+(pedalWidth), pedalTop);
		view1.moveTo((pedalDistance*2)+(pedalWidth*2)+pedalLeft, pedalTop);

		~phaserGroup.free;
		~flangerGroup.free;
		~wahGroup.free;
		~outputAudioStereoGroup.free;
		~flangerGroup=Group.new;
		~wahGroup=Group.after(~flangerhGroup);
		~phaserGroup=Group.after(~wahGroup);
		~outputAudioStereoGroup=Group.after(~phaserGroup);

		fSynth = Synth(\flanger,
			[\input_bus, firstInputChannel, \output_bus,~b1,\freqLFO,~knobFreqf.value,\ampLFO,~knobAmpf.value,\gfb,~knobGfb.value,\gff,~knobGff.value,\bypassf,~buttonf.value]
			,target:~flangerGroup);
		wSynth = Synth(\wahWah,
			[\input_bus, ~b1, \output_bus,~b2,\dur,~knobDurw.value,\amount,~knobAmountw.value,\bypassw,~buttonw.value]
			,target:~wahGroup);
		pSynth = Synth(\myphaser,
			[\input_bus, ~b2, \output_bus,~bout,\mod_freq,~knobFreqp.value,\depth,~knobDepthp.value,\bypassp,~buttonp.value]
			,target:~phaserGroup);
		outputAudioStereoSynth= Synth(\outputAudioStereo,[\master, ~knobMaster.value, \playSilence, ~buttonMaster.value, \pan, knobPan.value],target:~outputAudioStereoGroup);
	},{});
	//wah wah and phaser switch, the new configuration becomes FPW
	if (case==3,{
		view1.moveTo(pedalLeft+pedalDistance+(pedalWidth), pedalTop);
		view3.moveTo((pedalDistance*2)+(pedalWidth*2)+pedalLeft, pedalTop);

		~phaserGroup.free;
		~flangerGroup.free;
		~wahGroup.free;
		~outputAudioStereoGroup.free;
		~flangerGroup=Group.new;
		~phaserGroup=Group.after(~flangerGroup);
		~wahGroup=Group.after(~phaserGroup);
		~outputAudioStereoGroup=Group.after(~wahGroup);

		fSynth = Synth(\flanger,
			[\input_bus, firstInputChannel, \output_bus,~b1,\freqLFO,~knobFreqf.value,\ampLFO,~knobAmpf.value,\gfb,~knobGfb.value,\gff,~knobGff.value,\bypassf,~buttonf.value]
			,target:~flangerGroup);
		pSynth = Synth(\myphaser,
			[\input_bus, ~b1, \output_bus,~b2,\mod_freq,~knobFreqp.value,\depth,~knobDepthp.value,\bypassp,~buttonp.value]
			,target:~phaserGroup);
		wSynth = Synth(\wahWah,
			[\input_bus, ~b2, \output_bus,~bout,\dur,~knobDurw.value,\amount,~knobAmountw.value,\bypassw,~buttonw.value],
			target:~wahGroup);
		outputAudioStereoSynth= Synth(\outputAudioStereo,[\master, ~knobMaster.value, \playSilence, ~buttonMaster.value, \pan, knobPan.value],target:~outputAudioStereoGroup);
	},{});

	//flanger and wah wah switch, the new configuration becomes PWF
	if (case==4,{
		view3.moveTo(pedalLeft+pedalDistance+(pedalWidth), pedalTop);
		view2.moveTo((pedalDistance*2)+(pedalWidth*2)+pedalLeft, pedalTop);
		~phaserGroup.free;
		~flangerGroup.free;
		~wahGroup.free;
		~outputAudioStereoGroup.free;
		~phaserGroup=Group.new;
		~wahGroup=Group.after(~phaserGroup);
		~flangerGroup=Group.after(~wahGroup);
		~outputAudioStereoGroup=Group.after(~flangerGroup);

		pSynth = Synth(\myphaser,
			[\input_bus, firstInputChannel, \output_bus,~b1,\mod_freq,~knobFreqp.value,\depth,~knobDepthp.value,\bypassp,~buttonp.value]
			,target:~phaserGroup);
		wSynth = Synth(\wahWah,
			[\input_bus, ~b1, \output_bus,~b2,\dur,~knobDurw.value,\amount,~knobAmountw.value,\bypassw,~buttonw.value]
			,target:~wahGroup);
		fSynth = Synth(\flanger,
			[\input_bus, ~b2, \output_bus,~bout,\freqLFO,~knobFreqf.value,\ampLFO,~knobAmpf.value,\gfb,~knobGfb.value,\gff,~knobGff.value,\bypassf,~buttonf.value]
			,target:~flangerGroup);
		outputAudioStereoSynth= Synth(\outputAudioStereo,[\master, ~knobMaster.value, \playSilence, ~buttonMaster.value, \pan, knobPan.value],target:~outputAudioStereoGroup);
	},{});
	//wah wah and flanger switch, the new configuration becomes PFW
	if (case==5,{
		view2.moveTo(pedalLeft+pedalDistance+pedalWidth, pedalTop);
		view3.moveTo((pedalDistance*2)+(pedalWidth*2)+pedalLeft, pedalTop);
		~phaserGroup.free;
		~flangerGroup.free;
		~wahGroup.free;
		~outputAudioStereoGroup.free;
		~phaserGroup=Group.new;
		~flangerGroup=Group.after(~phaserGroup);
		~wahGroup=Group.after(~flangerGroup);
		~outputAudioStereoGroup=Group.after(~wahGroup);


		pSynth = Synth(\myphaser,
			[\input_bus, firstInputChannel, \output_bus,~b1,\mod_freq,~knobFreqp.value,\depth,~knobDepthp.value,\bypassp,~buttonp.value]
			,target:~phaserGroup);
		fSynth = Synth(\flanger,
			[\input_bus, ~b1, \output_bus,~b2,\freqLFO,~knobFreqf.value,\ampLFO,~knobAmpf.value,\gfb,~knobGfb.value,\gff,~knobGff.value,\bypassf,~buttonf.value]
			,target:~flangerGroup);
		wSynth = Synth(\wahWah,
			[\input_bus, ~b2, \output_bus,~bout,\dur,~knobDurw.value,\amount,~knobAmountw.value,\bypassw,~buttonw.value]
			,target:~wahGroup);
		outputAudioStereoSynth= Synth(\outputAudioStereo,[\master, ~knobMaster.value, \playSilence, ~buttonMaster.value, \pan, knobPan.value],target:~outputAudioStereoGroup);
	},{});

};



b = Button(w, Rect(scopeLeft+scopeWidth+3, scopeTop+scopeHeight-83, (pedalLeft+ (pedalWidth*4) +(pedalDistance*2)-scopeWidth)-(scopeLeft+scopeWidth+6), 40));

b.states =  ([
    ["TIME PLOT",Color.grey(0.2),myColor4],
	["FREQUENCY PLOT",Color.grey(0.2),myColor4]]);
b.font_(Font("Monaco",18));
~waveScope.free;
~waveScope2.free;


~scopein.free;
~scopeout.free;




b.action = { arg butt;
	if(butt==1,{~waveScope.stop;});
	if(butt==0,{~waveScope.stop;});

    p.visible = false;
	p = c.at(butt.value);
    p.visible = true;


	f.visible = false;
    f = d.at(butt.value);
    f.visible = true;



};


c = Array.fill(2, {
	view4= CompositeView(w, Rect(scopeLeft, scopeTop, scopeWidth, scopeHeight));
	view4.background=Color.black;
	view4.addFlowLayout;
	view4.visible = false;
    view4;

});



d = Array.fill(2, {
	view5= CompositeView(w, Rect(pedalLeft+ (pedalWidth*4) +(pedalDistance*2)-scopeWidth, scopeTop, scopeWidth, scopeHeight));
	view5.background=Color.black;
	view5.addFlowLayout;
	view5.visible = false;
    view5;

});

// create the ScopeViews and set their buffers
~waveScope = ScopeView(c[0], Rect(0, 0, scopeWidth, scopeHeight)).bufnum_(~bufferA.bufnum);
~waveScope2 = ScopeView(d[0],Rect(pedalLeft+ (pedalWidth*4) +(pedalDistance*2)-scopeWidth, scopeTop, scopeWidth, scopeHeight)).bufnum_(~bufferB.bufnum);

// important
~waveScope.server_(s);
~waveScope2.server_(s);


~waveScope.start;
~waveScope2.start;


// customize waveScope
~waveScope.style_(1)   // overlay channels
.waveColors_([myColor2]).background_(Color.black)
.xZoom_(1.7).yZoom_(7);   // scaling factors

// customize phaseScope
~waveScope2.style_(1)   // overlay channels
.waveColors_([myColor2,myColor2]).background_(Color.black)
.xZoom_(1.7).yZoom_(7);   // scaling factors




~waveScope.free;
~waveScope2.free;



~scopein.free;
~scopeout.free;



~scopein = FreqScopeView(c[1], Rect(scopeLeft, scopeTop, scopeWidth, scopeHeight)).active_(true);
~scopein.dbRange_(120);  // set amplitude range (in decibels)
~scopein.inBus_(~firstInputChannel);


~scopein.background_(Color.black).waveColors_([myColor2]); // set colors


~scopeout = FreqScopeView(d[1], Rect(pedalLeft+ (pedalWidth*4) +(pedalDistance*2)-scopeWidth, scopeTop, scopeWidth, scopeHeight)).active_(true);
~scopeout.dbRange_(120);  // set amplitude range (in decibels)
~busOutputStereo=Bus.new(index:0);
~scopeout.inBus_(~boutForFrequencyOutGraph);


~scopeout.background_(Color.black).waveColors_([myColor2,myColor2]); // set colors

p = c.at(0); // previous
p.visible = true; // show first one


f = d.at(0); // previous
f.visible = true; // show first one



insign = StaticText(w, Rect(scopeLeft-5,scopeTop,75,25));
//insign.background = (Color.new255(245.0,124.0,47.0));
insign.string_("INPUT");
insign.stringColor=myColor2;
insign.font = Font("Monaco", 20);
insign.align_(\center);

outsign = StaticText(w, Rect(pedalLeft+ (pedalWidth*4) +(pedalDistance*2)-scopeWidth+5,scopeTop,75,25));
//insign.background = (Color.new255(245.0,124.0,47.0));
outsign.string_("OUTPUT");
outsign.stringColor=myColor2;
outsign.font = Font("Monaco", 20);
outsign.align_(\center);











w.front;
w.onClose_({



	//~waveScope.kill;
	//~waveScope2.kill;
	~waveScope.free;
	~waveScope2.free;


	~scopein.kill;
	~scopeout.kill;
	~scopein.free;
	~scopeout.free;




	CmdPeriod.run});



)
