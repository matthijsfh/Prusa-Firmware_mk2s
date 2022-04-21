
#include "sim_nozzle.h"


void sim_nozzle_init(sim_nozzle_t* ps)
{
	ps->C =  6.0;
	ps->R = 24.5;
	ps->Ch = 2.2;
	ps->Rh = 2.0;
	ps->Cs = 0.34;
	ps->Rs = 10.0;
	ps->Ta = K_SHIFT + 25.5;
	ps->T = ps->Ta;
	ps->Th = ps->T;
	ps->Ts = ps->T; //[K] sensor temperature (avg)
	ps->P = 0;      //[W] heater power
	ps->Ex = 0.2;   //[J/mm] extrussion energy factor
	ps->vex = 0;    //[mm/s] extrussion speed
}

void sim_nozzle_set_extrussion_speed(sim_nozzle_t* ps, float vex)
{
	ps->vex = vex;
}

void sim_nozzle_cycle(sim_nozzle_t* ps, float dt)
{
//	float temp;
//	float noise_temp;
//	float noise_raw;
//	int16_t temp10;
//	int16_t raw;
	float E = ps->C * ps->T; //[J] total heat energy stored in heater block
	float Eh = ps->Ch * ps->Th; //[J] total heat energy stored in heater
	float Es = ps->Cs * ps->Ts; //[J] total heat energy stored in sensor
	float Pl = (ps->T - ps->Ta) / ps->R; //[W] power from heater block to ambient (leakage power)
	float Ph = (ps->Th - ps->T) / ps->Rh; //[W] power from heater to heater block
	float Ps = (ps->T - ps->Ts) / ps->Rs; //[W] power from heater block to sensor
	float Ehd = ((ps->P - Ph) * dt); //[J] heater energy increase
	float Ed = (Ph - (Pl + Ps)) * dt; //[J] heater block energy increase
	float Esd = (Ps * dt); //[J] sensor energy increase
	float Ex = (ps->Ex * ps->vex * dt);
	Ed -= Ex;
	//printf(" Pl=%3.0f  Ps=%3.0f\n", Pl, Ps);
	Eh += Ehd; //[J] heater result total heat energy
	E += Ed; //[J] heater block result total heat energy
	Es += Esd; //[J] sensor result total heat energy
	ps->Th = Eh / ps->Ch; //[K] result heater temperature
	ps->T = E / ps->C; //[K] result heater block temperature
	ps->Ts = Es / ps->Cs; //[K] result sensor temperature
//	temp = ps->Ts - 273.15;
//	noise_temp = (((float)rand() / RAND_MAX) - 0.5F) * 2.0F;
//	temp += noise_temp;
}
