//The ESP is not reading the DAC values correctly

#include "Adafruit_ADS1015.h" //Custom libraries were having an issue, so the ADS1115 & statistics were added manually
#include "Statistic.h"
#include <Wire.h>
#include <LiquidCrystal.h>
#include <EEPROM.h>
#include <LiquidCrystal_PCF8574.h>
LiquidCrystal_PCF8574 lcd(0x27);
//#include "DAC_COM.h"
//LiquidCrystal lcd(11, 10, 9, 13, 12, 14);
//Global Variables
#define IDN "SRS_ADC_ESP32"
#define gauges 4
//Communication
boolean calibrating = false;
String inputString = "";         // a String to hold incoming data
bool stringComplete = false;  // whether the string is complete
char inc[7];
byte code;
long timer;
boolean tcheck = false;
boolean mcheck = false;
char mystring[9];


//EEPROM stored values: calibration constants and gauge information
byte sizes[10] = {4,4,4,2,2,5,1,1,4,4}; //Size in the EEPROM of each configuration value
int Addr[sizeof(sizes)][gauges]; //Matrix that contains all address values
int leng=0;

//Structure and union for accessing calibration values;
typedef struct Calibration
{
  float a[gauges];
  float b[gauges];
  float c[gauges];
  unsigned short v[gauges];
  unsigned short w[gauges];
  char unit[5*gauges]; //Reserves 5 characters per gauge (mtorr being the largest expected), deg = char(186)
  byte calt[gauges]; //"Cal Type"
  byte avg[gauges];
  float multi[gauges];
  float offset[gauges];
};

union 
{
  Calibration val;
  byte bytes[sizeof(val)];
}cal;

//Unions for byte structure conversions for information from the serial line.
union { //byte structure for floats is reversed on arduinos. Sign bit is the first bit of byte[3]
  byte b[4];
  float o;
}b2f;
union{ //Note for int & long, stores is least significant[0] to most significant[end]
  byte b[2];
  unsigned int o;
}b2i;
union{
  byte b[4];
  long o;
}b2l;



//Values for Gauge Readings (Note: These are not in the calibration structure as they are more volitile.)
byte gauge;
int adc;
int adcAV[gauges]; //Raw 16-bit ADC measurement
float measurement[gauges]; //Measurement Value
int STD[gauges]; //array for storing previous readings standard deviation

Adafruit_ADS1115 ads; //Creates object for the ADC Device
Statistic adcReadings; //Creates object for utilizing the statistics tool


void(* resetFunc) (void) = 0; //*RST! on the serial line resets the program. Disconnecting and reconnecting has the same effect.
void setup(){
  Serial.begin(115200);
  if (!EEPROM.begin(sizeof(cal)))
  {
    Serial.println("failed to initialise EEPROM"); delay(1000000);
  }
//Read Stored Calibration Value
for (byte i = 0;i<sizeof(cal);i++){
  cal.bytes[i] = EEPROM.readByte(i);
}
//memset applies a zero mask to each of the measurement vectors
memset(adcAV,0,sizeof(adcAV));
memset(measurement,0,sizeof(measurement));
memset(STD,0,sizeof(STD));
inputString.reserve(200);
for (int j = 0;j<gauges;j++){
  Addr[0][j] = j*sizes[0];
};
for (int i = 1;i<=sizeof(sizes);i++){
  for (int j = 0;j<gauges;j++){
  Addr[i][j] = (j)*sizes[i]+Addr[i-1][3]+sizes[i-1];   
  }
};
  ads.setGain(GAIN_TWOTHIRDS); //Initialize ADS1115 board
  ads.begin();
  lcd.begin(20,4);
  lcd.setBacklight(255);
  lcd.clear();
  lcd.setCursor(0,1);
  lcd.print("      Ardu-DAC      ");
  lcd.setCursor(0,2);
  lcd.print("    SRS_ADC_V0.2    ");
  Serial.println(IDN);
//  delay(1000); //Delay to show the opening message
//  lcd.clear();
  adcReadings.clear();
  clr();
  }
  
void loop(){
  float sdev;
  long start = micros();
  if (!calibrating){
  for (byte n = 0; n<=3;n++){
  for (int i=0; i<=cal.val.avg[n]; i++){
    adc = ads.readADC_SingleEnded(n); //Note: takes 9 ms
    adcReadings.add(adc);
  }
  adcAV[n] = adcReadings.average();
  if (adcAV[n]<0){
    adcAV[n]=0;
  }
  STD[n] = adcReadings.unbiased_stdev();
  switch (cal.val.calt[n]){
  case 1:
    measurement[n]= linear(n,adcAV[n]);
    break;
    case 2:
    measurement[n] = quad(n,adcAV[n]);
    break;
    case 3:
    measurement[n] = sig(n,adcAV[n]);
    break;
    case 4:
    measurement[n] = pirani(n,adcAV[n]);
    break;
    case 5:
    measurement[n] = power(n,adcAV[n]);
    break;
    case 6:
    measurement[n] = logarithm(n,adcAV[n]);
    break;
    default:
    break;
  }
  measurement[n] = cal.val.multi[n]*measurement[n]+cal.val.offset[n]; //Unit conversion
  printm(n);
  adcReadings.clear();
  if (Serial.available()){ //Checks between measurements for serial input. Worst case response time is ~2 seconds @ 256 averages
    sEvent();
  }
  }
  if (tcheck){
    Request();
  }
}
double micro_delay = 4e5;
if (tcheck){
  micro_delay = 5e5;
}
  while ((micros()-start)<micro_delay){ //Ensures there a delay between the time measurments are repeated to ensure proper LCD/Serial reading
  if (Serial.available()){
      sEvent();
    }
}
}

void get_exp(float in){ // This forms a continuous loop
//  int exponent;
//  exponent = 0;
//  char sign;
//  if (in>10){
//    sign = '+';
//    while (in>10){
//      in = in/10;
//      exponent = exponent + 1;
//    }
//  } else if (in<1){
//    sign = '-';
//    while (in<1){
//      in = in*10;
//      exponent = exponent + 1;
//    }
//  }
//  dtostrf(in,1,6,mystring);
//  mystring[5] = 'e';
//  mystring[6] = sign;
//  char expo_char[2];
//  dtostrf(exponent,2,0,expo_char);
//  mystring[7] = expo_char[0];
//  mystring[8] = expo_char[1];
}

void printm(byte n){
//  if ((measurement[n]>1e5)||(measurement[n]<1e-5)){
//    get_exp(measurement[n]);
//  } else{
//  }
  boolean v = valid_check(n,adcAV[n]);
  if (v){
  dtostrf(measurement[n],9,9,mystring);
  lcd.setCursor(0,n);
  lcd.write(" #");
  lcd.write((byte)n+49);
  lcd.write(" ");
  for (int q = 0;q<9;q++){
    lcd.write(mystring[q]);  
  }
  lcd.write(" ");
  for (int q = 0;q<5;q++){
    char unit = cal.val.unit[n*5+q];
    if (((byte)unit==(byte)186)||((byte)unit==176)){
      lcd.write((char)223); //The character for degree symbol is 223 on the LCD, but it's 176/186 in matlab
    } else{
    lcd.write(unit);
  }
  }
  }
}

boolean valid_check(byte n, int input){
  boolean checker = true;
  if (input < cal.val.v[n]){
    under(n);
    checker = false;
  }
  if (input > cal.val.w[n]){
    over(n);
    checker = false;
  }
  return checker;
}

float linear(byte n, float input){
  return ((input-cal.val.b[n])/cal.val.a[n]);
}

float quad(byte n,float input){
  float first = sqrt(-4*(cal.val.a[n]*cal.val.c[n]+cal.val.a[n]*input)+cal.val.b[n]*cal.val.b[n]);
  float out = (first-cal.val.b[n])/(2*cal.val.a[n]);
  return out;
}

float sig(byte n, float input){ 
  return ((input-cal.val.c[n])/(cal.val.a[n]+cal.val.b[n]*(cal.val.c[n]-input)));
}

float pirani(byte n,float input){
  return ((input*input-cal.val.c[n])/(cal.val.a[n]+cal.val.b[n]*(cal.val.c[n]-input*input)));
}

float power(byte n,float input){
  return (exp(log((input-cal.val.c[n])/cal.val.a[n])/cal.val.b[n]));
}

float logarithm(byte n,float input){
  return (exp((input-cal.val.b[n])/cal.val.a[n]));
}

void under(byte n){
  lcd.setCursor(0,n);
  lcd.write(" #");
  lcd.write((char)(n+49));
  lcd.write(" No Connection   ");
}

void over(byte n){
  lcd.setCursor(0,n);
  lcd.write(" #");
  lcd.write((char)(n+49));
  lcd.write(" Overflow        ");
}

void sEvent(){
  while (Serial.available()) {
    char inChar = (char)Serial.read();
    if (inChar == '\n') {
      if ((inc[0]>96)&&(inc[0]<106&&(inc[0]!=102))){ //Note This forces the serial to accept the correct number of bytes after getting an 'a' thru 'e' byte
        if (leng>=(sizes[inc[0]-97]+2)){ //This is to eliminate errors where the values happen to contain the terminator bytes {32,10}
          stringComplete = true;
          break;
        }
      }
      else{
      stringComplete = true;
      break;
      }
    }
    inc[leng] = inChar;
    leng +=1;
  }
  if (stringComplete){
    Interpret();
    clr();
  }
}

void Interpret() { 
boolean cal = inc[0]>96&&inc[0]<(97+sizeof(sizes));
boolean IE3 = inc[0]=='*';
boolean req = inc[0]=='r';
if (!(cal||IE3||req)){
  Serial.println("Invalid serial code entered.");
}
if (IE3){
  IEEE();
}
if (req){
  if (inc[1]=='1'){
  Request();
  }
  else if (inc[1]=='0'){
    if (mcheck){
      Serial.println("Must r2 first.");
      return;
    }
    tcheck = !tcheck;
  }
  else if (inc[1]=='2'){
    if (tcheck&&!mcheck){
      Serial.println("Must r0 first.");
      return;
    }
    tcheck = !tcheck;
    mcheck = !mcheck;
  }
}
if (cal){
  Calibrate(inc[1]-49,inc[0]-97);
}
}

void Calibrate(byte g,byte c){
bool ck = Cal_Check(g,c);
if (ck){
  return;
}
for (int i = 0;i<sizes[c];i++){
  if((char)cal.bytes[Addr[c][g]+i]!=inc[i+2]){ //This simply checks if the byte is the same as what was recieved to avoid overwriting to the EEPROM
    cal.bytes[Addr[c][g]+i]=(byte)inc[i+2];
    EEPROM.put(Addr[c][g]+i,(byte)inc[i+2]);
  }
  EEPROM.commit(); //needed for ESP32
}
Serial.print("Changed ");
Serial.print((char)(c+97));
Serial.print(g+1);
Serial.print(" to be: ");
switch (sizes[c]){
case 1:
  Serial.print((byte)inc[2]);
  break;
case 2:
  b2i.b[0] = inc[2];
  b2i.b[1] = inc[3];
  Serial.print(b2i.o);
  break;
case 4:
  for (int i = 0;i<=3;i++){
    b2f.b[i]=inc[i+2];  
  }
  Serial.print(b2f.o);
  break;
default:
for (int i = 0;i<=4;i++){
  Serial.print(inc[i+2]); 
}
  break;
}
Serial.println("."); 
}

bool Cal_Check(byte g,byte c){
  if (g<0||g>3){
  Serial.println("Invalid Gauge Selection.");
  return true;
}
if (c==5){
    if (leng>7){
    Serial.println("Invalid input length. (No more than 5 bytes.)");
    return true;
  }
  else if (leng<7){ //Allows for incomplete character string for units
    for (int i = 7;i>leng;i--){
      inc[i-1] = ' ';
    }
  }
  
}
  else{
    if (leng!=(2+sizes[c])){
      Serial.print("Invalid input length. Please enter ");
      Serial.print(sizes[c]);
      Serial.println(" data bytes.");
      return true;
    }
  }
  return false;
}

void Request(){
    if (mcheck){
    for (int i = 0;i<gauges;i++){
    Serial.print(i+1);
    Serial.print(": ");
    Serial.print(measurement[i]);
    Serial.print(" ");
    for (int j = 0;j<5;j++){
      Serial.print(cal.val.unit[i*5+j]);
    }
    Serial.println("");
    }
    }
    else if(!mcheck){
    Serial.print('*');
    for (int i = 0;i<gauges;i++){
    b2i.o = adcAV[i];
    Serial.print((char)b2i.b[1]); //0 is the MSB, 1 is LSB, must match the way matlab interprets it
    Serial.print((char)b2i.b[0]);
    b2i.o = STD[i];
    Serial.print((char)b2i.b[1]);
    Serial.print((char)b2i.b[0]);
    }
  }
    Serial.println("");
}

//Added for being able to incorporate IEEE standard Commands (or make them up)
void IEEE(){
   String req = inc;
   if (req=="*IDN?"){
    Serial.println(IDN);
   }
   else if (req=="*CFG?"){
    cfg();
   }
   else if (req=="*RST!"){
    Serial.println("Resetting...");
    delay(1);
    resetFunc();
   }
   else if (req=="*HELP"){
    help();
   }
   else if (req=="*CAL?"){
    calprint();
   }
   else if (req=="*EEP?"){
    pEEPROM();
   }
   else if (req=="*CAL!"){
    calibrating = !calibrating;
    if (calibrating){
    Serial.println("*Calibrating...");
    }
    else{
      Serial.println("Calibration Finished.");
    }
   }
   else{
    I3Eerror();
   }
   clr();
}

void pEEPROM(){
  for (byte i=0;i<sizeof(cal);i++){
    char val = (char)EEPROM.readByte(i);
    Serial.print(val);
  }
  Serial.println("");
}

void I3Eerror(){
    Serial.println("IEEE COM not recognized.");
    }

void help(){
  Serial.println("Serial commands one basic structure, code-number-data.");
  Serial.print("There are ");
  Serial.print(sizeof(sizes));
  Serial.print(" codes. 'a', to ");
  Serial.print((char)(96+sizeof(sizes)));
  Serial.println(".");
  Serial.println("There are 4 gauges. Select gauge '#'.");
  Serial.println("'a' 'b' 'c' code are 4-byte float and will after 4 bytes are received and terminated.");
  Serial.println("");
  Serial.println("Request gauge info with 'r' and the g#. 15-bit");
  Serial.println("For continuous stream of measurements, use 'r0'");
}

void calprint(){
      Serial.print('*');
      delay(10);
  for (int i = 0;i<4;i++){
      Serial.print(i+1);
    for (int j = 0;j<sizeof(sizes);j++){
      for (int k = 0;k<sizes[j];k++){
        Serial.print((char)cal.bytes[Addr[j][i]+k]);
      }
    }
    Serial.println("");
  }
}

void cfg(){
  for (int i = 0;i<4;i++){
  Serial.print("# ");
  Serial.print(i+1);
  Serial.print(": ");
  Serial.print(cal.val.a[i]);
  Serial.print(", ");
  Serial.print(cal.val.b[i]);
  Serial.print(", ");
  Serial.print(cal.val.c[i]);
  Serial.print(", ");
  Serial.print(cal.val.v[i]);
  Serial.print(", ");
  Serial.print(cal.val.w[i]);
  Serial.print(", ");
  for (int j = 0;j<=4;j++){
  Serial.print((char)cal.val.unit[5*i+j]);
  }
  Serial.print(", ");
  Serial.print(cal.val.calt[i]);
  Serial.print(", ");
  Serial.print(cal.val.avg[i]);
  Serial.print(", ");
  Serial.print(cal.val.multi[i]);
  Serial.print(", ");
  Serial.println(cal.val.offset[i]);
  }
}

void clr(){
  if (inputString!=""){
    inputString = "";
  }
  stringComplete = false;
  memset(inc, 0, sizeof(inc));
  leng = 0;
}
