// sim_nozzle.h

#ifndef _SIM_NOZZLE_H
#define _SIM_NOZZLE_H

#include <inttypes.h>

#define K_SHIFT 273.15

typedef struct
{
	float C;   // [J/K] total heat capacity of entire heat block
	float R;   // [K/W] absolute thermal resistance between heat block and ambient
	float Ch;  // [J/K] total heat capacity of heater
	float Rh;  // [K/W] absolute thermal resistance between heater and heat block
	float Cs;  // [J/K] total heat capacity of sensor
	float Rs;  // [K/W] absolute thermal resistance between sensor and heat block
	float Ta;  // [K] ambient temperature
	float T;   // [K] heat block temperature (avg)
	float Th;  // [K] heater temperature (avg)
	float Ts;  // [K] sensor temperature (avg)
	float P;   // [W] heater power
	float Ex;  // [J/mm] extrussion energy factor
	float vex; // [mm/s] extrussion speed
} sim_nozzle_t;


extern void sim_nozzle_init(sim_nozzle_t* ps);
extern void sim_nozzle_set_extrussion_speed(sim_nozzle_t* ps, float vex);
extern void sim_nozzle_cycle(sim_nozzle_t* ps, float dt);


#endif // _SIM_NOZZLE_H
