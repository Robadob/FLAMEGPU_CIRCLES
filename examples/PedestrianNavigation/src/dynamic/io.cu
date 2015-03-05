
/*
* FLAME GPU v 1.4.0 for CUDA 6
* Copyright 2015 University of Sheffield.
* Author: Dr Paul Richmond
* Contact: p.richmond@sheffield.ac.uk (http://www.paulrichmond.staff.shef.ac.uk)
*
* University of Sheffield retain all intellectual property and
* proprietary rights in and to this software and related documentation.
* Any use, reproduction, disclosure, or distribution of this software
* and related documentation without an express license agreement from
* University of Sheffield is strictly prohibited.
*
* For terms of licence agreement please attached licence or view licence
* on www.flamegpu.com website.
*
*/

#include <cuda_runtime.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <math.h>
#include <limits.h>
	

// include header
#include "header.h"

float3 agent_maximum;
float3 agent_minimum;

void readIntArrayInput(char* buffer, int *array, unsigned int expected_items){
    unsigned int i = 0;
    const char s[2] = ",";
    char * token;

    token = strtok(buffer, s);
    while (token != NULL){
        if (i>=expected_items){
            printf("Error: Agent Memeory array has too many items, expected %d!\n", expected_items);
            exit(0);
        }
        
        array[i++] = atoi(token);
        
        token = strtok(NULL, s);
    }
    if (i != expected_items){
        printf("Error: Agent Memeory array has %d items, expected %d!\n", i, expected_items);
        exit(0);
    }
}

void readFloatArrayInput(char* buffer, float *array, unsigned int expected_items){
    unsigned int i = 0;
    const char s[2] = ",";
    char * token;

    token = strtok(buffer, s);
    while (token != NULL){
        if (i>=expected_items){
            printf("Error: Agent Memeory array has too many items, expected %d!\n", expected_items);
            exit(0);
        }
        
        array[i++] = (float)atof(token);
        
        token = strtok(NULL, s);
    }
    if (i != expected_items){
        printf("Error: Agent Memeory array has %d items, expected %d!\n", i, expected_items);
        exit(0);
    }
}

void saveIterationData(char* outputpath, int iteration_number, xmachine_memory_agent_list* h_agents_default, xmachine_memory_agent_list* d_agents_default, int h_xmachine_memory_agent_default_count,xmachine_memory_navmap_list* h_navmaps_static, xmachine_memory_navmap_list* d_navmaps_static, int h_xmachine_memory_navmap_static_count)
{
	cudaError_t cudaStatus;
	
	//Device to host memory transfer
	
	cudaStatus = cudaMemcpy( h_agents_default, d_agents_default, sizeof(xmachine_memory_agent_list), cudaMemcpyDeviceToHost);
	if (cudaStatus != cudaSuccess) 
	{
		fprintf(stderr,"Error Copying agent Agent default State Memory from GPU: %s\n", cudaGetErrorString(cudaStatus));
		exit(cudaStatus);
	}
	cudaStatus = cudaMemcpy( h_navmaps_static, d_navmaps_static, sizeof(xmachine_memory_navmap_list), cudaMemcpyDeviceToHost);
	if (cudaStatus != cudaSuccess) 
	{
		fprintf(stderr,"Error Copying navmap Agent static State Memory from GPU: %s\n", cudaGetErrorString(cudaStatus));
		exit(cudaStatus);
	}
	
	/* Pointer to file */
	FILE *file;
	char data[100];

	sprintf(data, "%s%i.xml", outputpath, iteration_number);
	//printf("Writing itteration %i data to %s\n", iteration_number, data);
	file = fopen(data, "w");
	fputs("<states>\n<itno>", file);
	sprintf(data, "%i", iteration_number);
	fputs(data, file);
	fputs("</itno>\n", file);
	fputs("<environment>\n" , file);
	fputs("</environment>\n" , file);

	//Write each agent agent to xml
	for (int i=0; i<h_xmachine_memory_agent_default_count; i++){
		fputs("<xagent>\n" , file);
		fputs("<name>agent</name>\n", file);
        
		fputs("<x>", file);
        sprintf(data, "%f", h_agents_default->x[i]);
		fputs(data, file);
		fputs("</x>\n", file);
        
		fputs("<y>", file);
        sprintf(data, "%f", h_agents_default->y[i]);
		fputs(data, file);
		fputs("</y>\n", file);
        
		fputs("<velx>", file);
        sprintf(data, "%f", h_agents_default->velx[i]);
		fputs(data, file);
		fputs("</velx>\n", file);
        
		fputs("<vely>", file);
        sprintf(data, "%f", h_agents_default->vely[i]);
		fputs(data, file);
		fputs("</vely>\n", file);
        
		fputs("<steer_x>", file);
        sprintf(data, "%f", h_agents_default->steer_x[i]);
		fputs(data, file);
		fputs("</steer_x>\n", file);
        
		fputs("<steer_y>", file);
        sprintf(data, "%f", h_agents_default->steer_y[i]);
		fputs(data, file);
		fputs("</steer_y>\n", file);
        
		fputs("<height>", file);
        sprintf(data, "%f", h_agents_default->height[i]);
		fputs(data, file);
		fputs("</height>\n", file);
        
		fputs("<exit_no>", file);
        sprintf(data, "%i", h_agents_default->exit_no[i]);
		fputs(data, file);
		fputs("</exit_no>\n", file);
        
		fputs("<speed>", file);
        sprintf(data, "%f", h_agents_default->speed[i]);
		fputs(data, file);
		fputs("</speed>\n", file);
        
		fputs("<lod>", file);
        sprintf(data, "%i", h_agents_default->lod[i]);
		fputs(data, file);
		fputs("</lod>\n", file);
        
		fputs("<animate>", file);
        sprintf(data, "%f", h_agents_default->animate[i]);
		fputs(data, file);
		fputs("</animate>\n", file);
        
		fputs("<animate_dir>", file);
        sprintf(data, "%i", h_agents_default->animate_dir[i]);
		fputs(data, file);
		fputs("</animate_dir>\n", file);
        
		fputs("</xagent>\n", file);
	}
	//Write each navmap agent to xml
	for (int i=0; i<h_xmachine_memory_navmap_static_count; i++){
		fputs("<xagent>\n" , file);
		fputs("<name>navmap</name>\n", file);
        
		fputs("<x>", file);
        sprintf(data, "%i", h_navmaps_static->x[i]);
		fputs(data, file);
		fputs("</x>\n", file);
        
		fputs("<y>", file);
        sprintf(data, "%i", h_navmaps_static->y[i]);
		fputs(data, file);
		fputs("</y>\n", file);
        
		fputs("<exit_no>", file);
        sprintf(data, "%i", h_navmaps_static->exit_no[i]);
		fputs(data, file);
		fputs("</exit_no>\n", file);
        
		fputs("<height>", file);
        sprintf(data, "%f", h_navmaps_static->height[i]);
		fputs(data, file);
		fputs("</height>\n", file);
        
		fputs("<collision_x>", file);
        sprintf(data, "%f", h_navmaps_static->collision_x[i]);
		fputs(data, file);
		fputs("</collision_x>\n", file);
        
		fputs("<collision_y>", file);
        sprintf(data, "%f", h_navmaps_static->collision_y[i]);
		fputs(data, file);
		fputs("</collision_y>\n", file);
        
		fputs("<exit0_x>", file);
        sprintf(data, "%f", h_navmaps_static->exit0_x[i]);
		fputs(data, file);
		fputs("</exit0_x>\n", file);
        
		fputs("<exit0_y>", file);
        sprintf(data, "%f", h_navmaps_static->exit0_y[i]);
		fputs(data, file);
		fputs("</exit0_y>\n", file);
        
		fputs("<exit1_x>", file);
        sprintf(data, "%f", h_navmaps_static->exit1_x[i]);
		fputs(data, file);
		fputs("</exit1_x>\n", file);
        
		fputs("<exit1_y>", file);
        sprintf(data, "%f", h_navmaps_static->exit1_y[i]);
		fputs(data, file);
		fputs("</exit1_y>\n", file);
        
		fputs("<exit2_x>", file);
        sprintf(data, "%f", h_navmaps_static->exit2_x[i]);
		fputs(data, file);
		fputs("</exit2_x>\n", file);
        
		fputs("<exit2_y>", file);
        sprintf(data, "%f", h_navmaps_static->exit2_y[i]);
		fputs(data, file);
		fputs("</exit2_y>\n", file);
        
		fputs("<exit3_x>", file);
        sprintf(data, "%f", h_navmaps_static->exit3_x[i]);
		fputs(data, file);
		fputs("</exit3_x>\n", file);
        
		fputs("<exit3_y>", file);
        sprintf(data, "%f", h_navmaps_static->exit3_y[i]);
		fputs(data, file);
		fputs("</exit3_y>\n", file);
        
		fputs("<exit4_x>", file);
        sprintf(data, "%f", h_navmaps_static->exit4_x[i]);
		fputs(data, file);
		fputs("</exit4_x>\n", file);
        
		fputs("<exit4_y>", file);
        sprintf(data, "%f", h_navmaps_static->exit4_y[i]);
		fputs(data, file);
		fputs("</exit4_y>\n", file);
        
		fputs("<exit5_x>", file);
        sprintf(data, "%f", h_navmaps_static->exit5_x[i]);
		fputs(data, file);
		fputs("</exit5_x>\n", file);
        
		fputs("<exit5_y>", file);
        sprintf(data, "%f", h_navmaps_static->exit5_y[i]);
		fputs(data, file);
		fputs("</exit5_y>\n", file);
        
		fputs("<exit6_x>", file);
        sprintf(data, "%f", h_navmaps_static->exit6_x[i]);
		fputs(data, file);
		fputs("</exit6_x>\n", file);
        
		fputs("<exit6_y>", file);
        sprintf(data, "%f", h_navmaps_static->exit6_y[i]);
		fputs(data, file);
		fputs("</exit6_y>\n", file);
        
		fputs("</xagent>\n", file);
	}
	
	

	fputs("</states>\n" , file);
	
	/* Close the file */
	fclose(file);
}

void readInitialStates(char* inputpath, xmachine_memory_agent_list* h_agents, int* h_xmachine_memory_agent_count,xmachine_memory_navmap_list* h_navmaps, int* h_xmachine_memory_navmap_count)
{

	int temp = 0;
	int* itno = &temp;

	/* Pointer to file */
	FILE *file;
	/* Char and char buffer for reading file to */
	char c = ' ';
	char buffer[10000];
	char agentname[1000];

	/* Pointer to x-memory for initial state data */
	/*xmachine * current_xmachine;*/
	/* Variables for checking tags */
	int reading, i;
	int in_tag, in_itno, in_name;
    int in_agent_x;
    int in_agent_y;
    int in_agent_velx;
    int in_agent_vely;
    int in_agent_steer_x;
    int in_agent_steer_y;
    int in_agent_height;
    int in_agent_exit_no;
    int in_agent_speed;
    int in_agent_lod;
    int in_agent_animate;
    int in_agent_animate_dir;
    int in_navmap_x;
    int in_navmap_y;
    int in_navmap_exit_no;
    int in_navmap_height;
    int in_navmap_collision_x;
    int in_navmap_collision_y;
    int in_navmap_exit0_x;
    int in_navmap_exit0_y;
    int in_navmap_exit1_x;
    int in_navmap_exit1_y;
    int in_navmap_exit2_x;
    int in_navmap_exit2_y;
    int in_navmap_exit3_x;
    int in_navmap_exit3_y;
    int in_navmap_exit4_x;
    int in_navmap_exit4_y;
    int in_navmap_exit5_x;
    int in_navmap_exit5_y;
    int in_navmap_exit6_x;
    int in_navmap_exit6_y;

	/* for continuous agents: set agent count to zero */	
	*h_xmachine_memory_agent_count = 0;
	
	/* Variables for initial state data */
	float agent_x;
	float agent_y;
	float agent_velx;
	float agent_vely;
	float agent_steer_x;
	float agent_steer_y;
	float agent_height;
	int agent_exit_no;
	float agent_speed;
	int agent_lod;
	float agent_animate;
	int agent_animate_dir;
	int navmap_x;
	int navmap_y;
	int navmap_exit_no;
	float navmap_height;
	float navmap_collision_x;
	float navmap_collision_y;
	float navmap_exit0_x;
	float navmap_exit0_y;
	float navmap_exit1_x;
	float navmap_exit1_y;
	float navmap_exit2_x;
	float navmap_exit2_y;
	float navmap_exit3_x;
	float navmap_exit3_y;
	float navmap_exit4_x;
	float navmap_exit4_y;
	float navmap_exit5_x;
	float navmap_exit5_y;
	float navmap_exit6_x;
	float navmap_exit6_y;
	
	/* Open config file to read-only */
	if((file = fopen(inputpath, "r"))==NULL)
	{
		printf("error opening initial states\n");
		exit(0);
	}
	
	/* Initialise variables */
    agent_maximum.x = 0;
    agent_maximum.y = 0;
    agent_maximum.z = 0;
    agent_minimum.x = 0;
    agent_minimum.y = 0;
    agent_minimum.z = 0;
	reading = 1;
	in_tag = 0;
	in_itno = 0;
	in_name = 0;
	in_agent_x = 0;
	in_agent_y = 0;
	in_agent_velx = 0;
	in_agent_vely = 0;
	in_agent_steer_x = 0;
	in_agent_steer_y = 0;
	in_agent_height = 0;
	in_agent_exit_no = 0;
	in_agent_speed = 0;
	in_agent_lod = 0;
	in_agent_animate = 0;
	in_agent_animate_dir = 0;
	in_navmap_x = 0;
	in_navmap_y = 0;
	in_navmap_exit_no = 0;
	in_navmap_height = 0;
	in_navmap_collision_x = 0;
	in_navmap_collision_y = 0;
	in_navmap_exit0_x = 0;
	in_navmap_exit0_y = 0;
	in_navmap_exit1_x = 0;
	in_navmap_exit1_y = 0;
	in_navmap_exit2_x = 0;
	in_navmap_exit2_y = 0;
	in_navmap_exit3_x = 0;
	in_navmap_exit3_y = 0;
	in_navmap_exit4_x = 0;
	in_navmap_exit4_y = 0;
	in_navmap_exit5_x = 0;
	in_navmap_exit5_y = 0;
	in_navmap_exit6_x = 0;
	in_navmap_exit6_y = 0;
	//set all agent values to 0
	//If this is not done then it will cause errors in emu mode where undefined memory is not 0
	for (int k=0; k<xmachine_memory_agent_MAX; k++)
	{	
		h_agents->x[k] = 0;
		h_agents->y[k] = 0;
		h_agents->velx[k] = 0;
		h_agents->vely[k] = 0;
		h_agents->steer_x[k] = 0;
		h_agents->steer_y[k] = 0;
		h_agents->height[k] = 0;
		h_agents->exit_no[k] = 0;
		h_agents->speed[k] = 0;
		h_agents->lod[k] = 0;
		h_agents->animate[k] = 0;
		h_agents->animate_dir[k] = 0;
	}
	
	//set all navmap values to 0
	//If this is not done then it will cause errors in emu mode where undefined memory is not 0
	for (int k=0; k<xmachine_memory_navmap_MAX; k++)
	{	
		h_navmaps->x[k] = 0;
		h_navmaps->y[k] = 0;
		h_navmaps->exit_no[k] = 0;
		h_navmaps->height[k] = 0;
		h_navmaps->collision_x[k] = 0;
		h_navmaps->collision_y[k] = 0;
		h_navmaps->exit0_x[k] = 0;
		h_navmaps->exit0_y[k] = 0;
		h_navmaps->exit1_x[k] = 0;
		h_navmaps->exit1_y[k] = 0;
		h_navmaps->exit2_x[k] = 0;
		h_navmaps->exit2_y[k] = 0;
		h_navmaps->exit3_x[k] = 0;
		h_navmaps->exit3_y[k] = 0;
		h_navmaps->exit4_x[k] = 0;
		h_navmaps->exit4_y[k] = 0;
		h_navmaps->exit5_x[k] = 0;
		h_navmaps->exit5_y[k] = 0;
		h_navmaps->exit6_x[k] = 0;
		h_navmaps->exit6_y[k] = 0;
	}
	

	/* Default variables for memory */
    agent_x = 0;
    agent_y = 0;
    agent_velx = 0;
    agent_vely = 0;
    agent_steer_x = 0;
    agent_steer_y = 0;
    agent_height = 0;
    agent_exit_no = 0;
    agent_speed = 0;
    agent_lod = 0;
    agent_animate = 0;
    agent_animate_dir = 0;
    navmap_x = 0;
    navmap_y = 0;
    navmap_exit_no = 0;
    navmap_height = 0;
    navmap_collision_x = 0;
    navmap_collision_y = 0;
    navmap_exit0_x = 0;
    navmap_exit0_y = 0;
    navmap_exit1_x = 0;
    navmap_exit1_y = 0;
    navmap_exit2_x = 0;
    navmap_exit2_y = 0;
    navmap_exit3_x = 0;
    navmap_exit3_y = 0;
    navmap_exit4_x = 0;
    navmap_exit4_y = 0;
    navmap_exit5_x = 0;
    navmap_exit5_y = 0;
    navmap_exit6_x = 0;
    navmap_exit6_y = 0;

	/* Read file until end of xml */
    i = 0;
	while(reading==1)
	{
		/* Get the next char from the file */
		c = (char)fgetc(file);
		
		/* If the end of a tag */
		if(c == '>')
		{
			/* Place 0 at end of buffer to make chars a string */
			buffer[i] = 0;
			
			if(strcmp(buffer, "states") == 0) reading = 1;
			if(strcmp(buffer, "/states") == 0) reading = 0;
			if(strcmp(buffer, "itno") == 0) in_itno = 1;
			if(strcmp(buffer, "/itno") == 0) in_itno = 0;
			if(strcmp(buffer, "name") == 0) in_name = 1;
			if(strcmp(buffer, "/name") == 0) in_name = 0;
			if(strcmp(buffer, "/xagent") == 0)
			{
				if(strcmp(agentname, "agent") == 0)
				{		
					if (*h_xmachine_memory_agent_count > xmachine_memory_agent_MAX){
						printf("ERROR: MAX Buffer size (%i) for agent agent exceeded whilst reading data\n", xmachine_memory_agent_MAX);
						// Close the file and stop reading
						fclose(file);
						exit(0);
					}
                    
					h_agents->x[*h_xmachine_memory_agent_count] = agent_x;//Check maximum x value
                    if(agent_maximum.x < agent_x)
                        agent_maximum.x = (float)agent_x;
                    //Check minimum x value
                    if(agent_minimum.x > agent_x)
                        agent_minimum.x = (float)agent_x;
                    
					h_agents->y[*h_xmachine_memory_agent_count] = agent_y;//Check maximum y value
                    if(agent_maximum.y < agent_y)
                        agent_maximum.y = (float)agent_y;
                    //Check minimum y value
                    if(agent_minimum.y > agent_y)
                        agent_minimum.y = (float)agent_y;
                    
					h_agents->velx[*h_xmachine_memory_agent_count] = agent_velx;
					h_agents->vely[*h_xmachine_memory_agent_count] = agent_vely;
					h_agents->steer_x[*h_xmachine_memory_agent_count] = agent_steer_x;
					h_agents->steer_y[*h_xmachine_memory_agent_count] = agent_steer_y;
					h_agents->height[*h_xmachine_memory_agent_count] = agent_height;
					h_agents->exit_no[*h_xmachine_memory_agent_count] = agent_exit_no;
					h_agents->speed[*h_xmachine_memory_agent_count] = agent_speed;
					h_agents->lod[*h_xmachine_memory_agent_count] = agent_lod;
					h_agents->animate[*h_xmachine_memory_agent_count] = agent_animate;
					h_agents->animate_dir[*h_xmachine_memory_agent_count] = agent_animate_dir;
					(*h_xmachine_memory_agent_count) ++;	
				}
				else if(strcmp(agentname, "navmap") == 0)
				{		
					if (*h_xmachine_memory_navmap_count > xmachine_memory_navmap_MAX){
						printf("ERROR: MAX Buffer size (%i) for agent navmap exceeded whilst reading data\n", xmachine_memory_navmap_MAX);
						// Close the file and stop reading
						fclose(file);
						exit(0);
					}
                    
					h_navmaps->x[*h_xmachine_memory_navmap_count] = navmap_x;//Check maximum x value
                    if(agent_maximum.x < navmap_x)
                        agent_maximum.x = (float)navmap_x;
                    //Check minimum x value
                    if(agent_minimum.x > navmap_x)
                        agent_minimum.x = (float)navmap_x;
                    
					h_navmaps->y[*h_xmachine_memory_navmap_count] = navmap_y;//Check maximum y value
                    if(agent_maximum.y < navmap_y)
                        agent_maximum.y = (float)navmap_y;
                    //Check minimum y value
                    if(agent_minimum.y > navmap_y)
                        agent_minimum.y = (float)navmap_y;
                    
					h_navmaps->exit_no[*h_xmachine_memory_navmap_count] = navmap_exit_no;
					h_navmaps->height[*h_xmachine_memory_navmap_count] = navmap_height;
					h_navmaps->collision_x[*h_xmachine_memory_navmap_count] = navmap_collision_x;
					h_navmaps->collision_y[*h_xmachine_memory_navmap_count] = navmap_collision_y;
					h_navmaps->exit0_x[*h_xmachine_memory_navmap_count] = navmap_exit0_x;
					h_navmaps->exit0_y[*h_xmachine_memory_navmap_count] = navmap_exit0_y;
					h_navmaps->exit1_x[*h_xmachine_memory_navmap_count] = navmap_exit1_x;
					h_navmaps->exit1_y[*h_xmachine_memory_navmap_count] = navmap_exit1_y;
					h_navmaps->exit2_x[*h_xmachine_memory_navmap_count] = navmap_exit2_x;
					h_navmaps->exit2_y[*h_xmachine_memory_navmap_count] = navmap_exit2_y;
					h_navmaps->exit3_x[*h_xmachine_memory_navmap_count] = navmap_exit3_x;
					h_navmaps->exit3_y[*h_xmachine_memory_navmap_count] = navmap_exit3_y;
					h_navmaps->exit4_x[*h_xmachine_memory_navmap_count] = navmap_exit4_x;
					h_navmaps->exit4_y[*h_xmachine_memory_navmap_count] = navmap_exit4_y;
					h_navmaps->exit5_x[*h_xmachine_memory_navmap_count] = navmap_exit5_x;
					h_navmaps->exit5_y[*h_xmachine_memory_navmap_count] = navmap_exit5_y;
					h_navmaps->exit6_x[*h_xmachine_memory_navmap_count] = navmap_exit6_x;
					h_navmaps->exit6_y[*h_xmachine_memory_navmap_count] = navmap_exit6_y;
					(*h_xmachine_memory_navmap_count) ++;	
				}
				else
				{
					printf("Warning: agent name undefined - '%s'\n", agentname);
				}
				

				
				/* Reset xagent variables */
                agent_x = 0;
                agent_y = 0;
                agent_velx = 0;
                agent_vely = 0;
                agent_steer_x = 0;
                agent_steer_y = 0;
                agent_height = 0;
                agent_exit_no = 0;
                agent_speed = 0;
                agent_lod = 0;
                agent_animate = 0;
                agent_animate_dir = 0;
                navmap_x = 0;
                navmap_y = 0;
                navmap_exit_no = 0;
                navmap_height = 0;
                navmap_collision_x = 0;
                navmap_collision_y = 0;
                navmap_exit0_x = 0;
                navmap_exit0_y = 0;
                navmap_exit1_x = 0;
                navmap_exit1_y = 0;
                navmap_exit2_x = 0;
                navmap_exit2_y = 0;
                navmap_exit3_x = 0;
                navmap_exit3_y = 0;
                navmap_exit4_x = 0;
                navmap_exit4_y = 0;
                navmap_exit5_x = 0;
                navmap_exit5_y = 0;
                navmap_exit6_x = 0;
                navmap_exit6_y = 0;

			}
			if(strcmp(buffer, "x") == 0) in_agent_x = 1;
			if(strcmp(buffer, "/x") == 0) in_agent_x = 0;
			if(strcmp(buffer, "y") == 0) in_agent_y = 1;
			if(strcmp(buffer, "/y") == 0) in_agent_y = 0;
			if(strcmp(buffer, "velx") == 0) in_agent_velx = 1;
			if(strcmp(buffer, "/velx") == 0) in_agent_velx = 0;
			if(strcmp(buffer, "vely") == 0) in_agent_vely = 1;
			if(strcmp(buffer, "/vely") == 0) in_agent_vely = 0;
			if(strcmp(buffer, "steer_x") == 0) in_agent_steer_x = 1;
			if(strcmp(buffer, "/steer_x") == 0) in_agent_steer_x = 0;
			if(strcmp(buffer, "steer_y") == 0) in_agent_steer_y = 1;
			if(strcmp(buffer, "/steer_y") == 0) in_agent_steer_y = 0;
			if(strcmp(buffer, "height") == 0) in_agent_height = 1;
			if(strcmp(buffer, "/height") == 0) in_agent_height = 0;
			if(strcmp(buffer, "exit_no") == 0) in_agent_exit_no = 1;
			if(strcmp(buffer, "/exit_no") == 0) in_agent_exit_no = 0;
			if(strcmp(buffer, "speed") == 0) in_agent_speed = 1;
			if(strcmp(buffer, "/speed") == 0) in_agent_speed = 0;
			if(strcmp(buffer, "lod") == 0) in_agent_lod = 1;
			if(strcmp(buffer, "/lod") == 0) in_agent_lod = 0;
			if(strcmp(buffer, "animate") == 0) in_agent_animate = 1;
			if(strcmp(buffer, "/animate") == 0) in_agent_animate = 0;
			if(strcmp(buffer, "animate_dir") == 0) in_agent_animate_dir = 1;
			if(strcmp(buffer, "/animate_dir") == 0) in_agent_animate_dir = 0;
			if(strcmp(buffer, "x") == 0) in_navmap_x = 1;
			if(strcmp(buffer, "/x") == 0) in_navmap_x = 0;
			if(strcmp(buffer, "y") == 0) in_navmap_y = 1;
			if(strcmp(buffer, "/y") == 0) in_navmap_y = 0;
			if(strcmp(buffer, "exit_no") == 0) in_navmap_exit_no = 1;
			if(strcmp(buffer, "/exit_no") == 0) in_navmap_exit_no = 0;
			if(strcmp(buffer, "height") == 0) in_navmap_height = 1;
			if(strcmp(buffer, "/height") == 0) in_navmap_height = 0;
			if(strcmp(buffer, "collision_x") == 0) in_navmap_collision_x = 1;
			if(strcmp(buffer, "/collision_x") == 0) in_navmap_collision_x = 0;
			if(strcmp(buffer, "collision_y") == 0) in_navmap_collision_y = 1;
			if(strcmp(buffer, "/collision_y") == 0) in_navmap_collision_y = 0;
			if(strcmp(buffer, "exit0_x") == 0) in_navmap_exit0_x = 1;
			if(strcmp(buffer, "/exit0_x") == 0) in_navmap_exit0_x = 0;
			if(strcmp(buffer, "exit0_y") == 0) in_navmap_exit0_y = 1;
			if(strcmp(buffer, "/exit0_y") == 0) in_navmap_exit0_y = 0;
			if(strcmp(buffer, "exit1_x") == 0) in_navmap_exit1_x = 1;
			if(strcmp(buffer, "/exit1_x") == 0) in_navmap_exit1_x = 0;
			if(strcmp(buffer, "exit1_y") == 0) in_navmap_exit1_y = 1;
			if(strcmp(buffer, "/exit1_y") == 0) in_navmap_exit1_y = 0;
			if(strcmp(buffer, "exit2_x") == 0) in_navmap_exit2_x = 1;
			if(strcmp(buffer, "/exit2_x") == 0) in_navmap_exit2_x = 0;
			if(strcmp(buffer, "exit2_y") == 0) in_navmap_exit2_y = 1;
			if(strcmp(buffer, "/exit2_y") == 0) in_navmap_exit2_y = 0;
			if(strcmp(buffer, "exit3_x") == 0) in_navmap_exit3_x = 1;
			if(strcmp(buffer, "/exit3_x") == 0) in_navmap_exit3_x = 0;
			if(strcmp(buffer, "exit3_y") == 0) in_navmap_exit3_y = 1;
			if(strcmp(buffer, "/exit3_y") == 0) in_navmap_exit3_y = 0;
			if(strcmp(buffer, "exit4_x") == 0) in_navmap_exit4_x = 1;
			if(strcmp(buffer, "/exit4_x") == 0) in_navmap_exit4_x = 0;
			if(strcmp(buffer, "exit4_y") == 0) in_navmap_exit4_y = 1;
			if(strcmp(buffer, "/exit4_y") == 0) in_navmap_exit4_y = 0;
			if(strcmp(buffer, "exit5_x") == 0) in_navmap_exit5_x = 1;
			if(strcmp(buffer, "/exit5_x") == 0) in_navmap_exit5_x = 0;
			if(strcmp(buffer, "exit5_y") == 0) in_navmap_exit5_y = 1;
			if(strcmp(buffer, "/exit5_y") == 0) in_navmap_exit5_y = 0;
			if(strcmp(buffer, "exit6_x") == 0) in_navmap_exit6_x = 1;
			if(strcmp(buffer, "/exit6_x") == 0) in_navmap_exit6_x = 0;
			if(strcmp(buffer, "exit6_y") == 0) in_navmap_exit6_y = 1;
			if(strcmp(buffer, "/exit6_y") == 0) in_navmap_exit6_y = 0;
			
			
			/* End of tag and reset buffer */
			in_tag = 0;
			i = 0;
		}
		/* If start of tag */
		else if(c == '<')
		{
			/* Place /0 at end of buffer to end numbers */
			buffer[i] = 0;
			/* Flag in tag */
			in_tag = 1;
			
			if(in_itno) *itno = atoi(buffer);
			if(in_name) strcpy(agentname, buffer);
			else
			{
				if(in_agent_x){ 
                    agent_x = (float) atof(buffer);    
                }
				if(in_agent_y){ 
                    agent_y = (float) atof(buffer);    
                }
				if(in_agent_velx){ 
                    agent_velx = (float) atof(buffer);    
                }
				if(in_agent_vely){ 
                    agent_vely = (float) atof(buffer);    
                }
				if(in_agent_steer_x){ 
                    agent_steer_x = (float) atof(buffer);    
                }
				if(in_agent_steer_y){ 
                    agent_steer_y = (float) atof(buffer);    
                }
				if(in_agent_height){ 
                    agent_height = (float) atof(buffer);    
                }
				if(in_agent_exit_no){ 
                    agent_exit_no = (int) atoi(buffer);    
                }
				if(in_agent_speed){ 
                    agent_speed = (float) atof(buffer);    
                }
				if(in_agent_lod){ 
                    agent_lod = (int) atoi(buffer);    
                }
				if(in_agent_animate){ 
                    agent_animate = (float) atof(buffer);    
                }
				if(in_agent_animate_dir){ 
                    agent_animate_dir = (int) atoi(buffer);    
                }
				if(in_navmap_x){ 
                    navmap_x = (int) atoi(buffer);    
                }
				if(in_navmap_y){ 
                    navmap_y = (int) atoi(buffer);    
                }
				if(in_navmap_exit_no){ 
                    navmap_exit_no = (int) atoi(buffer);    
                }
				if(in_navmap_height){ 
                    navmap_height = (float) atof(buffer);    
                }
				if(in_navmap_collision_x){ 
                    navmap_collision_x = (float) atof(buffer);    
                }
				if(in_navmap_collision_y){ 
                    navmap_collision_y = (float) atof(buffer);    
                }
				if(in_navmap_exit0_x){ 
                    navmap_exit0_x = (float) atof(buffer);    
                }
				if(in_navmap_exit0_y){ 
                    navmap_exit0_y = (float) atof(buffer);    
                }
				if(in_navmap_exit1_x){ 
                    navmap_exit1_x = (float) atof(buffer);    
                }
				if(in_navmap_exit1_y){ 
                    navmap_exit1_y = (float) atof(buffer);    
                }
				if(in_navmap_exit2_x){ 
                    navmap_exit2_x = (float) atof(buffer);    
                }
				if(in_navmap_exit2_y){ 
                    navmap_exit2_y = (float) atof(buffer);    
                }
				if(in_navmap_exit3_x){ 
                    navmap_exit3_x = (float) atof(buffer);    
                }
				if(in_navmap_exit3_y){ 
                    navmap_exit3_y = (float) atof(buffer);    
                }
				if(in_navmap_exit4_x){ 
                    navmap_exit4_x = (float) atof(buffer);    
                }
				if(in_navmap_exit4_y){ 
                    navmap_exit4_y = (float) atof(buffer);    
                }
				if(in_navmap_exit5_x){ 
                    navmap_exit5_x = (float) atof(buffer);    
                }
				if(in_navmap_exit5_y){ 
                    navmap_exit5_y = (float) atof(buffer);    
                }
				if(in_navmap_exit6_x){ 
                    navmap_exit6_x = (float) atof(buffer);    
                }
				if(in_navmap_exit6_y){ 
                    navmap_exit6_y = (float) atof(buffer);    
                }
				
			}
			
			/* Reset buffer */
			i = 0;
		}
		/* If in tag put read char into buffer */
		else if(in_tag)
		{
			buffer[i] = c;
			i++;
		}
		/* If in data read char into buffer */
		else
		{
			buffer[i] = c;
			i++;
		}
	}
	/* Close the file */
	fclose(file);
}

float3 getMaximumBounds(){
    return agent_maximum;
}

float3 getMinimumBounds(){
    return agent_minimum;
}

