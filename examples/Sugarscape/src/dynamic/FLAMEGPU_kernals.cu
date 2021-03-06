

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

#ifndef _FLAMEGPU_KERNELS_H_
#define _FLAMEGPU_KERNELS_H_

#include "header.h"


/* Agent count constants */

__constant__ int d_xmachine_memory_agent_count;

/* Agent state count constants */

__constant__ int d_xmachine_memory_agent_default_count;


/* Message constants */

/* cell_state Message variables */
//Discrete Partitioning Variables
__constant__ int d_message_cell_state_range;     /**< range of the discrete message*/
__constant__ int d_message_cell_state_width;     /**< with of the message grid*/

/* movement_request Message variables */
//Discrete Partitioning Variables
__constant__ int d_message_movement_request_range;     /**< range of the discrete message*/
__constant__ int d_message_movement_request_width;     /**< with of the message grid*/

/* movement_response Message variables */
//Discrete Partitioning Variables
__constant__ int d_message_movement_response_range;     /**< range of the discrete message*/
__constant__ int d_message_movement_response_width;     /**< with of the message grid*/

	
    
//include each function file

#include "functions.c"
    
/* Texture bindings */
/* cell_state Message Bindings */texture<int, 1, cudaReadModeElementType> tex_xmachine_message_cell_state_location_id;
__constant__ int d_tex_xmachine_message_cell_state_location_id_offset;texture<int, 1, cudaReadModeElementType> tex_xmachine_message_cell_state_state;
__constant__ int d_tex_xmachine_message_cell_state_state_offset;texture<int, 1, cudaReadModeElementType> tex_xmachine_message_cell_state_env_sugar_level;
__constant__ int d_tex_xmachine_message_cell_state_env_sugar_level_offset;

/* movement_request Message Bindings */texture<int, 1, cudaReadModeElementType> tex_xmachine_message_movement_request_agent_id;
__constant__ int d_tex_xmachine_message_movement_request_agent_id_offset;texture<int, 1, cudaReadModeElementType> tex_xmachine_message_movement_request_location_id;
__constant__ int d_tex_xmachine_message_movement_request_location_id_offset;texture<int, 1, cudaReadModeElementType> tex_xmachine_message_movement_request_sugar_level;
__constant__ int d_tex_xmachine_message_movement_request_sugar_level_offset;texture<int, 1, cudaReadModeElementType> tex_xmachine_message_movement_request_metabolism;
__constant__ int d_tex_xmachine_message_movement_request_metabolism_offset;

/* movement_response Message Bindings */texture<int, 1, cudaReadModeElementType> tex_xmachine_message_movement_response_location_id;
__constant__ int d_tex_xmachine_message_movement_response_location_id_offset;texture<int, 1, cudaReadModeElementType> tex_xmachine_message_movement_response_agent_id;
__constant__ int d_tex_xmachine_message_movement_response_agent_id_offset;

    
#define WRAP(x,m) (((x)<m)?(x):(x%m)) /**< Simple wrap */
#define sWRAP(x,m) (((x)<m)?(((x)<0)?(m+(x)):(x)):(m-(x))) /**<signed integer wrap (no modulus) for negatives where 2m > |x| > m */

//PADDING WILL ONLY AVOID SM CONFLICTS FOR 32BIT
//SM_OFFSET REQUIRED AS FERMI STARTS INDEXING MEMORY FROM LOCATION 0 (i.e. NULL)??
__constant__ int d_SM_START;
__constant__ int d_PADDING;

//SM addressing macro to avoid conflicts (32 bit only)
#define SHARE_INDEX(i, s) ((((s) + d_PADDING)* (i))+d_SM_START) /**<offset struct size by padding to avoid bank conflicts */

//if doubel support is needed then define the following function which requires sm_13 or later
#ifdef _DOUBLE_SUPPORT_REQUIRED_
__inline__ __device__ double tex1DfetchDouble(texture<int2, 1, cudaReadModeElementType> tex, int i)
{
	int2 v = tex1Dfetch(tex, i);
  //IF YOU HAVE AN ERROR HERE THEN YOU ARE USING DOUBLE VALUES IN AGENT MEMORY AND NOT COMPILING FOR DOUBLE SUPPORTED HARDWARE
  //To compile for double supported hardware change the CUDA Build rule property "Use sm_13 Architecture (double support)" on the CUDA-Specific Propert Page of the CUDA Build Rule for simulation.cu
	return __hiloint2double(v.y, v.x);
}
#endif

/* Helper functions */
/** next_cell
 * Function used for finding the next cell when using spatial partitioning
 * Upddates the relative cell variable which can have value of -1, 0 or +1
 * @param relative_cell pointer to the relative cell position
 * @return boolean if there is a next cell. True unless relative_Cell value was 1,1,1
 */
__device__ int next_cell3D(int3* relative_cell)
{
	if (relative_cell->x < 1)
	{
		relative_cell->x++;
		return true;
	}
	relative_cell->x = -1;

	if (relative_cell->y < 1)
	{
		relative_cell->y++;
		return true;
	}
	relative_cell->y = -1;
	
	if (relative_cell->z < 1)
	{
		relative_cell->z++;
		return true;
	}
	relative_cell->z = -1;
	
	return false;
}

/** next_cell2D
 * Function used for finding the next cell when using spatial partitioning. Z component is ignored
 * Upddates the relative cell variable which can have value of -1, 0 or +1
 * @param relative_cell pointer to the relative cell position
 * @return boolean if there is a next cell. True unless relative_Cell value was 1,1
 */
__device__ int next_cell2D(int3* relative_cell)
{
	if (relative_cell->x < 1)
	{
		relative_cell->x++;
		return true;
	}
	relative_cell->x = -1;

	if (relative_cell->y < 1)
	{
		relative_cell->y++;
		return true;
	}
	relative_cell->y = -1;
	
	return false;
}


/** metabolise_and_growback_function_filter
 *	Global condition function. Flags the scan input state to true if the condition is met
 * @param currentState xmachine_memory_agent_list representing agent i the current state
 */
 __global__ void metabolise_and_growback_function_filter(xmachine_memory_agent_list* currentState)
 {
	//global thread index
	int index = (blockIdx.x*blockDim.x) + threadIdx.x;
	
	//check thread max
	if (index < d_xmachine_memory_agent_count){
	
		//apply the filter
		if (currentState->state[index]!=AGENT_STATE_MOVEMENT_UNRESOLVED)
		{	currentState->_scan_input[index] = 1;
		}
		else
		{
			currentState->_scan_input[index] = 0;
		}
	
	}
 }

////////////////////////////////////////////////////////////////////////////////////////////////////////
/* Dyanamically created agent agent functions */

/** reset_agent_scan_input
 * agent agent reset scan input function
 * @param agents The xmachine_memory_agent_list agent list
 */
__global__ void reset_agent_scan_input(xmachine_memory_agent_list* agents){

	//global thread index
	int index = (blockIdx.x*blockDim.x) + threadIdx.x;

	agents->_position[index] = 0;
	agents->_scan_input[index] = 0;
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/* Dyanamically created cell_state message functions */


/* Message functions */

template <int AGENT_TYPE>
__device__ void add_cell_state_message(xmachine_message_cell_state_list* messages, int location_id, int state, int env_sugar_level){
	if (AGENT_TYPE == DISCRETE_2D){
		int width = (blockDim.x * gridDim.x);
		int2 global_position;
		global_position.x = (blockIdx.x * blockDim.x) + threadIdx.x;
		global_position.y = (blockIdx.y * blockDim.y) + threadIdx.y;

		int index = global_position.x + (global_position.y * width);

		
		messages->location_id[index] = location_id;			
		messages->state[index] = state;			
		messages->env_sugar_level[index] = env_sugar_level;			
	}
	//else CONTINUOUS agents can not write to discrete space
}

//Used by continuous agents this accesses messages with texture cache. agent_x and agent_y are discrete positions in the message space
__device__ xmachine_message_cell_state* get_first_cell_state_message_continuous(xmachine_message_cell_state_list* messages,  int agent_x, int agent_y){

	//shared memory get from offset dependant on sm usage in function
	extern __shared__ int sm_data [];

	xmachine_message_cell_state* message_share = (xmachine_message_cell_state*)&sm_data[0];
	
	int range = d_message_cell_state_range;
	int width = d_message_cell_state_width;
	
	int2 global_position;
	global_position.x = sWRAP(agent_x-range , width);
	global_position.y = sWRAP(agent_y-range , width);
	

	int index = ((global_position.y)* width) + global_position.x;
	
	xmachine_message_cell_state temp_message;
	temp_message._position = make_int2(agent_x, agent_y);
	temp_message._relative = make_int2(-range, -range);

	temp_message.location_id = tex1Dfetch(tex_xmachine_message_cell_state_location_id, index + d_tex_xmachine_message_cell_state_location_id_offset);temp_message.state = tex1Dfetch(tex_xmachine_message_cell_state_state, index + d_tex_xmachine_message_cell_state_state_offset);temp_message.env_sugar_level = tex1Dfetch(tex_xmachine_message_cell_state_env_sugar_level, index + d_tex_xmachine_message_cell_state_env_sugar_level_offset);
	
	message_share[threadIdx.x] = temp_message;

	//return top left of messages
	return &message_share[threadIdx.x];
}

//Get next cell_state message  continuous
//Used by continuous agents this accesses messages with texture cache (agent position in discrete space was set when accessing first message)
__device__ xmachine_message_cell_state* get_next_cell_state_message_continuous(xmachine_message_cell_state* message, xmachine_message_cell_state_list* messages){

	//shared memory get from offset dependant on sm usage in function
	extern __shared__ int sm_data [];

	xmachine_message_cell_state* message_share = (xmachine_message_cell_state*)&sm_data[0];
	
	int range = d_message_cell_state_range;
	int width = d_message_cell_state_width;

	//Get previous position
	int2 previous_relative = message->_relative;

	//exit if at (range, range)
	if (previous_relative.x == (range))
        if (previous_relative.y == (range))
		    return false;

	//calculate next message relative position
	int2 next_relative = previous_relative;
	next_relative.x += 1;
	if ((next_relative.x)>range){
		next_relative.x = -range;
		next_relative.y = previous_relative.y + 1;
	}

	//skip own message
	if (next_relative.x == 0)
        if (next_relative.y == 0)
		    next_relative.x += 1;

	int2 global_position;
	global_position.x =	sWRAP(message->_position.x + next_relative.x, width);
	global_position.y = sWRAP(message->_position.y + next_relative.y, width);

	int index = ((global_position.y)* width) + (global_position.x);
	
	xmachine_message_cell_state temp_message;
	temp_message._position = message->_position;
	temp_message._relative = next_relative;

	temp_message.location_id = tex1Dfetch(tex_xmachine_message_cell_state_location_id, index + d_tex_xmachine_message_cell_state_location_id_offset);	temp_message.state = tex1Dfetch(tex_xmachine_message_cell_state_state, index + d_tex_xmachine_message_cell_state_state_offset);	temp_message.env_sugar_level = tex1Dfetch(tex_xmachine_message_cell_state_env_sugar_level, index + d_tex_xmachine_message_cell_state_env_sugar_level_offset);	

	message_share[threadIdx.x] = temp_message;

	return &message_share[threadIdx.x];
}

//method used by discrete agents accessing discrete messages to load messages into shared memory
__device__ void cell_state_message_to_sm(xmachine_message_cell_state_list* messages, char* message_share, int sm_index, int global_index){
		xmachine_message_cell_state temp_message;
		
		temp_message.location_id = messages->location_id[global_index];		
		temp_message.state = messages->state[global_index];		
		temp_message.env_sugar_level = messages->env_sugar_level[global_index];		

	  int message_index = SHARE_INDEX(sm_index, sizeof(xmachine_message_cell_state));
	  xmachine_message_cell_state* sm_message = ((xmachine_message_cell_state*)&message_share[message_index]);
	  sm_message[0] = temp_message;
}

//Get first cell_state message 
//Used by discrete agents this accesses messages with texture cache. Agent position is determined by position in the grid/block
//Possibility of upto 8 thread divergences
__device__ xmachine_message_cell_state* get_first_cell_state_message_discrete(xmachine_message_cell_state_list* messages){

	//shared memory get from offset dependant on sm usage in function
	extern __shared__ int sm_data [];

	char* message_share = (char*)&sm_data[0];
  
	__syncthreads();

	int range = d_message_cell_state_range;
	int width = d_message_cell_state_width;
	int sm_grid_width = blockDim.x + (range* 2);
	
	
	int2 global_position;
	global_position.x = (blockIdx.x * blockDim.x) + threadIdx.x;
	global_position.y = (blockIdx.y * blockDim.y) + threadIdx.y;
	int index = global_position.x + (global_position.y * width);
	

	//calculate the position in shared memeory of first load
	int2 sm_pos;
	sm_pos.x = threadIdx.x + range;
	sm_pos.y = threadIdx.y + range;
	int sm_index = (sm_pos.y * sm_grid_width) + sm_pos.x;

	//each thread loads to shared memeory (coalesced read)
	cell_state_message_to_sm(messages, message_share, sm_index, index);

	//check for edge conditions
	int left_border = (threadIdx.x < range);
	int right_border = (threadIdx.x >= (blockDim.x-range));
	int top_border = (threadIdx.y < range);
	int bottom_border = (threadIdx.y >= (blockDim.y-range));

	
	int  border_index;
	int  sm_border_index;

	//left
	if (left_border){	
		int2 border_index_2d = global_position;
		border_index_2d.x = sWRAP(border_index_2d.x - range, width);
		border_index = (border_index_2d.y * width) + border_index_2d.x;
		sm_border_index = (sm_pos.y * sm_grid_width) + threadIdx.x;
		
		cell_state_message_to_sm(messages, message_share, sm_border_index, border_index);
	}

	//right
	if (right_border){
		int2 border_index_2d = global_position;
		border_index_2d.x = sWRAP(border_index_2d.x + range, width);
		border_index = (border_index_2d.y * width) + border_index_2d.x;
		sm_border_index = (sm_pos.y * sm_grid_width) + (sm_pos.x + range);

		cell_state_message_to_sm(messages, message_share, sm_border_index, border_index);
	}

	//top
	if (top_border){
		int2 border_index_2d = global_position;
		border_index_2d.y = sWRAP(border_index_2d.y - range, width);
		border_index = (border_index_2d.y * width) + border_index_2d.x;
		sm_border_index = (threadIdx.y * sm_grid_width) + sm_pos.x;

		cell_state_message_to_sm(messages, message_share, sm_border_index, border_index);
	}

	//bottom
	if (bottom_border){
		int2 border_index_2d = global_position;
		border_index_2d.y = sWRAP(border_index_2d.y + range, width);
		border_index = (border_index_2d.y * width) + border_index_2d.x;
		sm_border_index = ((sm_pos.y + range) * sm_grid_width) + sm_pos.x;

		cell_state_message_to_sm(messages, message_share, sm_border_index, border_index);
	}

	//top left
	if ((top_border)&&(left_border)){	
		int2 border_index_2d = global_position;
		border_index_2d.x = sWRAP(border_index_2d.x - range, width);
		border_index_2d.y = sWRAP(border_index_2d.y - range, width);
		border_index = (border_index_2d.y * width) + border_index_2d.x;
		sm_border_index = (threadIdx.y * sm_grid_width) + threadIdx.x;
		
		cell_state_message_to_sm(messages, message_share, sm_border_index, border_index);
	}

	//top right
	if ((top_border)&&(right_border)){	
		int2 border_index_2d = global_position;
		border_index_2d.x = sWRAP(border_index_2d.x + range, width);
		border_index_2d.y = sWRAP(border_index_2d.y - range, width);
		border_index = (border_index_2d.y * width) + border_index_2d.x;
		sm_border_index = (threadIdx.y * sm_grid_width) + (sm_pos.x + range);
		
		cell_state_message_to_sm(messages, message_share, sm_border_index, border_index);
	}

	//bottom right
	if ((bottom_border)&&(right_border)){	
		int2 border_index_2d = global_position;
		border_index_2d.x = sWRAP(border_index_2d.x + range, width);
		border_index_2d.y = sWRAP(border_index_2d.y + range, width);
		border_index = (border_index_2d.y * width) + border_index_2d.x;
		sm_border_index = ((sm_pos.y + range) * sm_grid_width) + (sm_pos.x + range);
		
		cell_state_message_to_sm(messages, message_share, sm_border_index, border_index);
	}

	//bottom left
	if ((bottom_border)&&(left_border)){	
		int2 border_index_2d = global_position;
		border_index_2d.x = sWRAP(border_index_2d.x - range, width);
		border_index_2d.y = sWRAP(border_index_2d.y + range, width);
		border_index = (border_index_2d.y * width) + border_index_2d.x;
		sm_border_index = ((sm_pos.y + range) * sm_grid_width) + threadIdx.x;
		
		cell_state_message_to_sm(messages, message_share, sm_border_index, border_index);
	}

	__syncthreads();
	
  
	//top left of block position sm index
	sm_index = (threadIdx.y * sm_grid_width) + threadIdx.x;
	
	int message_index = SHARE_INDEX(sm_index, sizeof(xmachine_message_cell_state));
	xmachine_message_cell_state* temp = ((xmachine_message_cell_state*)&message_share[message_index]);
	temp->_relative = make_int2(-range, -range); //this is the relative position
	return temp;
}

//Get next cell_state message 
//Used by discrete agents this accesses messages through shared memeory which were all loaded on first message retrieval call.
__device__ xmachine_message_cell_state* get_next_cell_state_message_discrete(xmachine_message_cell_state* message, xmachine_message_cell_state_list* messages){

	//shared memory get from offset dependant on sm usage in function
	extern __shared__ int sm_data [];

	char* message_share = (char*)&sm_data[0];
  
	__syncthreads();
	
	int range = d_message_cell_state_range;
	int sm_grid_width = blockDim.x+(range*2);


	//Get previous position
	int2 previous_relative = message->_relative;

	//exit if at (range, range)
	if (previous_relative.x == range)
        if (previous_relative.y == range)
		    return false;

	//calculate next message relative position
	int2 next_relative = previous_relative;
	next_relative.x += 1;
	if ((next_relative.x)>range){
		next_relative.x = -range;
		next_relative.y = previous_relative.y + 1;
	}

	//skip own message
	if (next_relative.x == 0)
        if (next_relative.y == 0)
		    next_relative.x += 1;


	//calculate the next message position
	int2 next_position;// = block_position+next_relative;
	//offset next position by the sm border size
	next_position.x = threadIdx.x + next_relative.x + range;
	next_position.y = threadIdx.y + next_relative.y + range;

	int sm_index = next_position.x + (next_position.y * sm_grid_width);
	
	__syncthreads();
  
	int message_index = SHARE_INDEX(sm_index, sizeof(xmachine_message_cell_state));
	xmachine_message_cell_state* temp = ((xmachine_message_cell_state*)&message_share[message_index]);
	temp->_relative = next_relative; //this is the relative position
	return temp;
}

//Get first cell_state message
template <int AGENT_TYPE>
__device__ xmachine_message_cell_state* get_first_cell_state_message(xmachine_message_cell_state_list* messages, int agent_x, int agent_y){

	if (AGENT_TYPE == DISCRETE_2D)	//use shared memory method
		return get_first_cell_state_message_discrete(messages);
	else	//use texture fetching method
		return get_first_cell_state_message_continuous(messages, agent_x, agent_y);

}

//Get next cell_state message
template <int AGENT_TYPE>
__device__ xmachine_message_cell_state* get_next_cell_state_message(xmachine_message_cell_state* message, xmachine_message_cell_state_list* messages){

	if (AGENT_TYPE == DISCRETE_2D)	//use shared memory method
		return get_next_cell_state_message_discrete(message, messages);
	else	//use texture fetching method
		return get_next_cell_state_message_continuous(message, messages);

}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/* Dyanamically created movement_request message functions */


/* Message functions */

template <int AGENT_TYPE>
__device__ void add_movement_request_message(xmachine_message_movement_request_list* messages, int agent_id, int location_id, int sugar_level, int metabolism){
	if (AGENT_TYPE == DISCRETE_2D){
		int width = (blockDim.x * gridDim.x);
		int2 global_position;
		global_position.x = (blockIdx.x * blockDim.x) + threadIdx.x;
		global_position.y = (blockIdx.y * blockDim.y) + threadIdx.y;

		int index = global_position.x + (global_position.y * width);

		
		messages->agent_id[index] = agent_id;			
		messages->location_id[index] = location_id;			
		messages->sugar_level[index] = sugar_level;			
		messages->metabolism[index] = metabolism;			
	}
	//else CONTINUOUS agents can not write to discrete space
}

//Used by continuous agents this accesses messages with texture cache. agent_x and agent_y are discrete positions in the message space
__device__ xmachine_message_movement_request* get_first_movement_request_message_continuous(xmachine_message_movement_request_list* messages,  int agent_x, int agent_y){

	//shared memory get from offset dependant on sm usage in function
	extern __shared__ int sm_data [];

	xmachine_message_movement_request* message_share = (xmachine_message_movement_request*)&sm_data[0];
	
	int range = d_message_movement_request_range;
	int width = d_message_movement_request_width;
	
	int2 global_position;
	global_position.x = sWRAP(agent_x-range , width);
	global_position.y = sWRAP(agent_y-range , width);
	

	int index = ((global_position.y)* width) + global_position.x;
	
	xmachine_message_movement_request temp_message;
	temp_message._position = make_int2(agent_x, agent_y);
	temp_message._relative = make_int2(-range, -range);

	temp_message.agent_id = tex1Dfetch(tex_xmachine_message_movement_request_agent_id, index + d_tex_xmachine_message_movement_request_agent_id_offset);temp_message.location_id = tex1Dfetch(tex_xmachine_message_movement_request_location_id, index + d_tex_xmachine_message_movement_request_location_id_offset);temp_message.sugar_level = tex1Dfetch(tex_xmachine_message_movement_request_sugar_level, index + d_tex_xmachine_message_movement_request_sugar_level_offset);temp_message.metabolism = tex1Dfetch(tex_xmachine_message_movement_request_metabolism, index + d_tex_xmachine_message_movement_request_metabolism_offset);
	
	message_share[threadIdx.x] = temp_message;

	//return top left of messages
	return &message_share[threadIdx.x];
}

//Get next movement_request message  continuous
//Used by continuous agents this accesses messages with texture cache (agent position in discrete space was set when accessing first message)
__device__ xmachine_message_movement_request* get_next_movement_request_message_continuous(xmachine_message_movement_request* message, xmachine_message_movement_request_list* messages){

	//shared memory get from offset dependant on sm usage in function
	extern __shared__ int sm_data [];

	xmachine_message_movement_request* message_share = (xmachine_message_movement_request*)&sm_data[0];
	
	int range = d_message_movement_request_range;
	int width = d_message_movement_request_width;

	//Get previous position
	int2 previous_relative = message->_relative;

	//exit if at (range, range)
	if (previous_relative.x == (range))
        if (previous_relative.y == (range))
		    return false;

	//calculate next message relative position
	int2 next_relative = previous_relative;
	next_relative.x += 1;
	if ((next_relative.x)>range){
		next_relative.x = -range;
		next_relative.y = previous_relative.y + 1;
	}

	//skip own message
	if (next_relative.x == 0)
        if (next_relative.y == 0)
		    next_relative.x += 1;

	int2 global_position;
	global_position.x =	sWRAP(message->_position.x + next_relative.x, width);
	global_position.y = sWRAP(message->_position.y + next_relative.y, width);

	int index = ((global_position.y)* width) + (global_position.x);
	
	xmachine_message_movement_request temp_message;
	temp_message._position = message->_position;
	temp_message._relative = next_relative;

	temp_message.agent_id = tex1Dfetch(tex_xmachine_message_movement_request_agent_id, index + d_tex_xmachine_message_movement_request_agent_id_offset);	temp_message.location_id = tex1Dfetch(tex_xmachine_message_movement_request_location_id, index + d_tex_xmachine_message_movement_request_location_id_offset);	temp_message.sugar_level = tex1Dfetch(tex_xmachine_message_movement_request_sugar_level, index + d_tex_xmachine_message_movement_request_sugar_level_offset);	temp_message.metabolism = tex1Dfetch(tex_xmachine_message_movement_request_metabolism, index + d_tex_xmachine_message_movement_request_metabolism_offset);	

	message_share[threadIdx.x] = temp_message;

	return &message_share[threadIdx.x];
}

//method used by discrete agents accessing discrete messages to load messages into shared memory
__device__ void movement_request_message_to_sm(xmachine_message_movement_request_list* messages, char* message_share, int sm_index, int global_index){
		xmachine_message_movement_request temp_message;
		
		temp_message.agent_id = messages->agent_id[global_index];		
		temp_message.location_id = messages->location_id[global_index];		
		temp_message.sugar_level = messages->sugar_level[global_index];		
		temp_message.metabolism = messages->metabolism[global_index];		

	  int message_index = SHARE_INDEX(sm_index, sizeof(xmachine_message_movement_request));
	  xmachine_message_movement_request* sm_message = ((xmachine_message_movement_request*)&message_share[message_index]);
	  sm_message[0] = temp_message;
}

//Get first movement_request message 
//Used by discrete agents this accesses messages with texture cache. Agent position is determined by position in the grid/block
//Possibility of upto 8 thread divergences
__device__ xmachine_message_movement_request* get_first_movement_request_message_discrete(xmachine_message_movement_request_list* messages){

	//shared memory get from offset dependant on sm usage in function
	extern __shared__ int sm_data [];

	char* message_share = (char*)&sm_data[0];
  
	__syncthreads();

	int range = d_message_movement_request_range;
	int width = d_message_movement_request_width;
	int sm_grid_width = blockDim.x + (range* 2);
	
	
	int2 global_position;
	global_position.x = (blockIdx.x * blockDim.x) + threadIdx.x;
	global_position.y = (blockIdx.y * blockDim.y) + threadIdx.y;
	int index = global_position.x + (global_position.y * width);
	

	//calculate the position in shared memeory of first load
	int2 sm_pos;
	sm_pos.x = threadIdx.x + range;
	sm_pos.y = threadIdx.y + range;
	int sm_index = (sm_pos.y * sm_grid_width) + sm_pos.x;

	//each thread loads to shared memeory (coalesced read)
	movement_request_message_to_sm(messages, message_share, sm_index, index);

	//check for edge conditions
	int left_border = (threadIdx.x < range);
	int right_border = (threadIdx.x >= (blockDim.x-range));
	int top_border = (threadIdx.y < range);
	int bottom_border = (threadIdx.y >= (blockDim.y-range));

	
	int  border_index;
	int  sm_border_index;

	//left
	if (left_border){	
		int2 border_index_2d = global_position;
		border_index_2d.x = sWRAP(border_index_2d.x - range, width);
		border_index = (border_index_2d.y * width) + border_index_2d.x;
		sm_border_index = (sm_pos.y * sm_grid_width) + threadIdx.x;
		
		movement_request_message_to_sm(messages, message_share, sm_border_index, border_index);
	}

	//right
	if (right_border){
		int2 border_index_2d = global_position;
		border_index_2d.x = sWRAP(border_index_2d.x + range, width);
		border_index = (border_index_2d.y * width) + border_index_2d.x;
		sm_border_index = (sm_pos.y * sm_grid_width) + (sm_pos.x + range);

		movement_request_message_to_sm(messages, message_share, sm_border_index, border_index);
	}

	//top
	if (top_border){
		int2 border_index_2d = global_position;
		border_index_2d.y = sWRAP(border_index_2d.y - range, width);
		border_index = (border_index_2d.y * width) + border_index_2d.x;
		sm_border_index = (threadIdx.y * sm_grid_width) + sm_pos.x;

		movement_request_message_to_sm(messages, message_share, sm_border_index, border_index);
	}

	//bottom
	if (bottom_border){
		int2 border_index_2d = global_position;
		border_index_2d.y = sWRAP(border_index_2d.y + range, width);
		border_index = (border_index_2d.y * width) + border_index_2d.x;
		sm_border_index = ((sm_pos.y + range) * sm_grid_width) + sm_pos.x;

		movement_request_message_to_sm(messages, message_share, sm_border_index, border_index);
	}

	//top left
	if ((top_border)&&(left_border)){	
		int2 border_index_2d = global_position;
		border_index_2d.x = sWRAP(border_index_2d.x - range, width);
		border_index_2d.y = sWRAP(border_index_2d.y - range, width);
		border_index = (border_index_2d.y * width) + border_index_2d.x;
		sm_border_index = (threadIdx.y * sm_grid_width) + threadIdx.x;
		
		movement_request_message_to_sm(messages, message_share, sm_border_index, border_index);
	}

	//top right
	if ((top_border)&&(right_border)){	
		int2 border_index_2d = global_position;
		border_index_2d.x = sWRAP(border_index_2d.x + range, width);
		border_index_2d.y = sWRAP(border_index_2d.y - range, width);
		border_index = (border_index_2d.y * width) + border_index_2d.x;
		sm_border_index = (threadIdx.y * sm_grid_width) + (sm_pos.x + range);
		
		movement_request_message_to_sm(messages, message_share, sm_border_index, border_index);
	}

	//bottom right
	if ((bottom_border)&&(right_border)){	
		int2 border_index_2d = global_position;
		border_index_2d.x = sWRAP(border_index_2d.x + range, width);
		border_index_2d.y = sWRAP(border_index_2d.y + range, width);
		border_index = (border_index_2d.y * width) + border_index_2d.x;
		sm_border_index = ((sm_pos.y + range) * sm_grid_width) + (sm_pos.x + range);
		
		movement_request_message_to_sm(messages, message_share, sm_border_index, border_index);
	}

	//bottom left
	if ((bottom_border)&&(left_border)){	
		int2 border_index_2d = global_position;
		border_index_2d.x = sWRAP(border_index_2d.x - range, width);
		border_index_2d.y = sWRAP(border_index_2d.y + range, width);
		border_index = (border_index_2d.y * width) + border_index_2d.x;
		sm_border_index = ((sm_pos.y + range) * sm_grid_width) + threadIdx.x;
		
		movement_request_message_to_sm(messages, message_share, sm_border_index, border_index);
	}

	__syncthreads();
	
  
	//top left of block position sm index
	sm_index = (threadIdx.y * sm_grid_width) + threadIdx.x;
	
	int message_index = SHARE_INDEX(sm_index, sizeof(xmachine_message_movement_request));
	xmachine_message_movement_request* temp = ((xmachine_message_movement_request*)&message_share[message_index]);
	temp->_relative = make_int2(-range, -range); //this is the relative position
	return temp;
}

//Get next movement_request message 
//Used by discrete agents this accesses messages through shared memeory which were all loaded on first message retrieval call.
__device__ xmachine_message_movement_request* get_next_movement_request_message_discrete(xmachine_message_movement_request* message, xmachine_message_movement_request_list* messages){

	//shared memory get from offset dependant on sm usage in function
	extern __shared__ int sm_data [];

	char* message_share = (char*)&sm_data[0];
  
	__syncthreads();
	
	int range = d_message_movement_request_range;
	int sm_grid_width = blockDim.x+(range*2);


	//Get previous position
	int2 previous_relative = message->_relative;

	//exit if at (range, range)
	if (previous_relative.x == range)
        if (previous_relative.y == range)
		    return false;

	//calculate next message relative position
	int2 next_relative = previous_relative;
	next_relative.x += 1;
	if ((next_relative.x)>range){
		next_relative.x = -range;
		next_relative.y = previous_relative.y + 1;
	}

	//skip own message
	if (next_relative.x == 0)
        if (next_relative.y == 0)
		    next_relative.x += 1;


	//calculate the next message position
	int2 next_position;// = block_position+next_relative;
	//offset next position by the sm border size
	next_position.x = threadIdx.x + next_relative.x + range;
	next_position.y = threadIdx.y + next_relative.y + range;

	int sm_index = next_position.x + (next_position.y * sm_grid_width);
	
	__syncthreads();
  
	int message_index = SHARE_INDEX(sm_index, sizeof(xmachine_message_movement_request));
	xmachine_message_movement_request* temp = ((xmachine_message_movement_request*)&message_share[message_index]);
	temp->_relative = next_relative; //this is the relative position
	return temp;
}

//Get first movement_request message
template <int AGENT_TYPE>
__device__ xmachine_message_movement_request* get_first_movement_request_message(xmachine_message_movement_request_list* messages, int agent_x, int agent_y){

	if (AGENT_TYPE == DISCRETE_2D)	//use shared memory method
		return get_first_movement_request_message_discrete(messages);
	else	//use texture fetching method
		return get_first_movement_request_message_continuous(messages, agent_x, agent_y);

}

//Get next movement_request message
template <int AGENT_TYPE>
__device__ xmachine_message_movement_request* get_next_movement_request_message(xmachine_message_movement_request* message, xmachine_message_movement_request_list* messages){

	if (AGENT_TYPE == DISCRETE_2D)	//use shared memory method
		return get_next_movement_request_message_discrete(message, messages);
	else	//use texture fetching method
		return get_next_movement_request_message_continuous(message, messages);

}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/* Dyanamically created movement_response message functions */


/* Message functions */

template <int AGENT_TYPE>
__device__ void add_movement_response_message(xmachine_message_movement_response_list* messages, int location_id, int agent_id){
	if (AGENT_TYPE == DISCRETE_2D){
		int width = (blockDim.x * gridDim.x);
		int2 global_position;
		global_position.x = (blockIdx.x * blockDim.x) + threadIdx.x;
		global_position.y = (blockIdx.y * blockDim.y) + threadIdx.y;

		int index = global_position.x + (global_position.y * width);

		
		messages->location_id[index] = location_id;			
		messages->agent_id[index] = agent_id;			
	}
	//else CONTINUOUS agents can not write to discrete space
}

//Used by continuous agents this accesses messages with texture cache. agent_x and agent_y are discrete positions in the message space
__device__ xmachine_message_movement_response* get_first_movement_response_message_continuous(xmachine_message_movement_response_list* messages,  int agent_x, int agent_y){

	//shared memory get from offset dependant on sm usage in function
	extern __shared__ int sm_data [];

	xmachine_message_movement_response* message_share = (xmachine_message_movement_response*)&sm_data[0];
	
	int range = d_message_movement_response_range;
	int width = d_message_movement_response_width;
	
	int2 global_position;
	global_position.x = sWRAP(agent_x-range , width);
	global_position.y = sWRAP(agent_y-range , width);
	

	int index = ((global_position.y)* width) + global_position.x;
	
	xmachine_message_movement_response temp_message;
	temp_message._position = make_int2(agent_x, agent_y);
	temp_message._relative = make_int2(-range, -range);

	temp_message.location_id = tex1Dfetch(tex_xmachine_message_movement_response_location_id, index + d_tex_xmachine_message_movement_response_location_id_offset);temp_message.agent_id = tex1Dfetch(tex_xmachine_message_movement_response_agent_id, index + d_tex_xmachine_message_movement_response_agent_id_offset);
	
	message_share[threadIdx.x] = temp_message;

	//return top left of messages
	return &message_share[threadIdx.x];
}

//Get next movement_response message  continuous
//Used by continuous agents this accesses messages with texture cache (agent position in discrete space was set when accessing first message)
__device__ xmachine_message_movement_response* get_next_movement_response_message_continuous(xmachine_message_movement_response* message, xmachine_message_movement_response_list* messages){

	//shared memory get from offset dependant on sm usage in function
	extern __shared__ int sm_data [];

	xmachine_message_movement_response* message_share = (xmachine_message_movement_response*)&sm_data[0];
	
	int range = d_message_movement_response_range;
	int width = d_message_movement_response_width;

	//Get previous position
	int2 previous_relative = message->_relative;

	//exit if at (range, range)
	if (previous_relative.x == (range))
        if (previous_relative.y == (range))
		    return false;

	//calculate next message relative position
	int2 next_relative = previous_relative;
	next_relative.x += 1;
	if ((next_relative.x)>range){
		next_relative.x = -range;
		next_relative.y = previous_relative.y + 1;
	}

	//skip own message
	if (next_relative.x == 0)
        if (next_relative.y == 0)
		    next_relative.x += 1;

	int2 global_position;
	global_position.x =	sWRAP(message->_position.x + next_relative.x, width);
	global_position.y = sWRAP(message->_position.y + next_relative.y, width);

	int index = ((global_position.y)* width) + (global_position.x);
	
	xmachine_message_movement_response temp_message;
	temp_message._position = message->_position;
	temp_message._relative = next_relative;

	temp_message.location_id = tex1Dfetch(tex_xmachine_message_movement_response_location_id, index + d_tex_xmachine_message_movement_response_location_id_offset);	temp_message.agent_id = tex1Dfetch(tex_xmachine_message_movement_response_agent_id, index + d_tex_xmachine_message_movement_response_agent_id_offset);	

	message_share[threadIdx.x] = temp_message;

	return &message_share[threadIdx.x];
}

//method used by discrete agents accessing discrete messages to load messages into shared memory
__device__ void movement_response_message_to_sm(xmachine_message_movement_response_list* messages, char* message_share, int sm_index, int global_index){
		xmachine_message_movement_response temp_message;
		
		temp_message.location_id = messages->location_id[global_index];		
		temp_message.agent_id = messages->agent_id[global_index];		

	  int message_index = SHARE_INDEX(sm_index, sizeof(xmachine_message_movement_response));
	  xmachine_message_movement_response* sm_message = ((xmachine_message_movement_response*)&message_share[message_index]);
	  sm_message[0] = temp_message;
}

//Get first movement_response message 
//Used by discrete agents this accesses messages with texture cache. Agent position is determined by position in the grid/block
//Possibility of upto 8 thread divergences
__device__ xmachine_message_movement_response* get_first_movement_response_message_discrete(xmachine_message_movement_response_list* messages){

	//shared memory get from offset dependant on sm usage in function
	extern __shared__ int sm_data [];

	char* message_share = (char*)&sm_data[0];
  
	__syncthreads();

	int range = d_message_movement_response_range;
	int width = d_message_movement_response_width;
	int sm_grid_width = blockDim.x + (range* 2);
	
	
	int2 global_position;
	global_position.x = (blockIdx.x * blockDim.x) + threadIdx.x;
	global_position.y = (blockIdx.y * blockDim.y) + threadIdx.y;
	int index = global_position.x + (global_position.y * width);
	

	//calculate the position in shared memeory of first load
	int2 sm_pos;
	sm_pos.x = threadIdx.x + range;
	sm_pos.y = threadIdx.y + range;
	int sm_index = (sm_pos.y * sm_grid_width) + sm_pos.x;

	//each thread loads to shared memeory (coalesced read)
	movement_response_message_to_sm(messages, message_share, sm_index, index);

	//check for edge conditions
	int left_border = (threadIdx.x < range);
	int right_border = (threadIdx.x >= (blockDim.x-range));
	int top_border = (threadIdx.y < range);
	int bottom_border = (threadIdx.y >= (blockDim.y-range));

	
	int  border_index;
	int  sm_border_index;

	//left
	if (left_border){	
		int2 border_index_2d = global_position;
		border_index_2d.x = sWRAP(border_index_2d.x - range, width);
		border_index = (border_index_2d.y * width) + border_index_2d.x;
		sm_border_index = (sm_pos.y * sm_grid_width) + threadIdx.x;
		
		movement_response_message_to_sm(messages, message_share, sm_border_index, border_index);
	}

	//right
	if (right_border){
		int2 border_index_2d = global_position;
		border_index_2d.x = sWRAP(border_index_2d.x + range, width);
		border_index = (border_index_2d.y * width) + border_index_2d.x;
		sm_border_index = (sm_pos.y * sm_grid_width) + (sm_pos.x + range);

		movement_response_message_to_sm(messages, message_share, sm_border_index, border_index);
	}

	//top
	if (top_border){
		int2 border_index_2d = global_position;
		border_index_2d.y = sWRAP(border_index_2d.y - range, width);
		border_index = (border_index_2d.y * width) + border_index_2d.x;
		sm_border_index = (threadIdx.y * sm_grid_width) + sm_pos.x;

		movement_response_message_to_sm(messages, message_share, sm_border_index, border_index);
	}

	//bottom
	if (bottom_border){
		int2 border_index_2d = global_position;
		border_index_2d.y = sWRAP(border_index_2d.y + range, width);
		border_index = (border_index_2d.y * width) + border_index_2d.x;
		sm_border_index = ((sm_pos.y + range) * sm_grid_width) + sm_pos.x;

		movement_response_message_to_sm(messages, message_share, sm_border_index, border_index);
	}

	//top left
	if ((top_border)&&(left_border)){	
		int2 border_index_2d = global_position;
		border_index_2d.x = sWRAP(border_index_2d.x - range, width);
		border_index_2d.y = sWRAP(border_index_2d.y - range, width);
		border_index = (border_index_2d.y * width) + border_index_2d.x;
		sm_border_index = (threadIdx.y * sm_grid_width) + threadIdx.x;
		
		movement_response_message_to_sm(messages, message_share, sm_border_index, border_index);
	}

	//top right
	if ((top_border)&&(right_border)){	
		int2 border_index_2d = global_position;
		border_index_2d.x = sWRAP(border_index_2d.x + range, width);
		border_index_2d.y = sWRAP(border_index_2d.y - range, width);
		border_index = (border_index_2d.y * width) + border_index_2d.x;
		sm_border_index = (threadIdx.y * sm_grid_width) + (sm_pos.x + range);
		
		movement_response_message_to_sm(messages, message_share, sm_border_index, border_index);
	}

	//bottom right
	if ((bottom_border)&&(right_border)){	
		int2 border_index_2d = global_position;
		border_index_2d.x = sWRAP(border_index_2d.x + range, width);
		border_index_2d.y = sWRAP(border_index_2d.y + range, width);
		border_index = (border_index_2d.y * width) + border_index_2d.x;
		sm_border_index = ((sm_pos.y + range) * sm_grid_width) + (sm_pos.x + range);
		
		movement_response_message_to_sm(messages, message_share, sm_border_index, border_index);
	}

	//bottom left
	if ((bottom_border)&&(left_border)){	
		int2 border_index_2d = global_position;
		border_index_2d.x = sWRAP(border_index_2d.x - range, width);
		border_index_2d.y = sWRAP(border_index_2d.y + range, width);
		border_index = (border_index_2d.y * width) + border_index_2d.x;
		sm_border_index = ((sm_pos.y + range) * sm_grid_width) + threadIdx.x;
		
		movement_response_message_to_sm(messages, message_share, sm_border_index, border_index);
	}

	__syncthreads();
	
  
	//top left of block position sm index
	sm_index = (threadIdx.y * sm_grid_width) + threadIdx.x;
	
	int message_index = SHARE_INDEX(sm_index, sizeof(xmachine_message_movement_response));
	xmachine_message_movement_response* temp = ((xmachine_message_movement_response*)&message_share[message_index]);
	temp->_relative = make_int2(-range, -range); //this is the relative position
	return temp;
}

//Get next movement_response message 
//Used by discrete agents this accesses messages through shared memeory which were all loaded on first message retrieval call.
__device__ xmachine_message_movement_response* get_next_movement_response_message_discrete(xmachine_message_movement_response* message, xmachine_message_movement_response_list* messages){

	//shared memory get from offset dependant on sm usage in function
	extern __shared__ int sm_data [];

	char* message_share = (char*)&sm_data[0];
  
	__syncthreads();
	
	int range = d_message_movement_response_range;
	int sm_grid_width = blockDim.x+(range*2);


	//Get previous position
	int2 previous_relative = message->_relative;

	//exit if at (range, range)
	if (previous_relative.x == range)
        if (previous_relative.y == range)
		    return false;

	//calculate next message relative position
	int2 next_relative = previous_relative;
	next_relative.x += 1;
	if ((next_relative.x)>range){
		next_relative.x = -range;
		next_relative.y = previous_relative.y + 1;
	}

	//skip own message
	if (next_relative.x == 0)
        if (next_relative.y == 0)
		    next_relative.x += 1;


	//calculate the next message position
	int2 next_position;// = block_position+next_relative;
	//offset next position by the sm border size
	next_position.x = threadIdx.x + next_relative.x + range;
	next_position.y = threadIdx.y + next_relative.y + range;

	int sm_index = next_position.x + (next_position.y * sm_grid_width);
	
	__syncthreads();
  
	int message_index = SHARE_INDEX(sm_index, sizeof(xmachine_message_movement_response));
	xmachine_message_movement_response* temp = ((xmachine_message_movement_response*)&message_share[message_index]);
	temp->_relative = next_relative; //this is the relative position
	return temp;
}

//Get first movement_response message
template <int AGENT_TYPE>
__device__ xmachine_message_movement_response* get_first_movement_response_message(xmachine_message_movement_response_list* messages, int agent_x, int agent_y){

	if (AGENT_TYPE == DISCRETE_2D)	//use shared memory method
		return get_first_movement_response_message_discrete(messages);
	else	//use texture fetching method
		return get_first_movement_response_message_continuous(messages, agent_x, agent_y);

}

//Get next movement_response message
template <int AGENT_TYPE>
__device__ xmachine_message_movement_response* get_next_movement_response_message(xmachine_message_movement_response* message, xmachine_message_movement_response_list* messages){

	if (AGENT_TYPE == DISCRETE_2D)	//use shared memory method
		return get_next_movement_response_message_discrete(message, messages);
	else	//use texture fetching method
		return get_next_movement_response_message_continuous(message, messages);

}


	
/////////////////////////////////////////////////////////////////////////////////////////////////////////
/* Dynamically created GPU kernels  */



/**
 *
 */
__global__ void GPUFLAME_metabolise_and_growback(xmachine_memory_agent_list* agents){
	
	
	//discrete agent: index is position in 2D agent grid
	int width = (blockDim.x * gridDim.x);
	int2 global_position;
	global_position.x = (blockIdx.x * blockDim.x) + threadIdx.x;
	global_position.y = (blockIdx.y * blockDim.y) + threadIdx.y;
	int index = global_position.x + (global_position.y * width);
	

	//SoA to AoS - xmachine_memory_metabolise_and_growback Coalesced memory read (arrays point to first item for agent index)
	xmachine_memory_agent agent;
	agent.location_id = agents->location_id[index];
	agent.agent_id = agents->agent_id[index];
	agent.state = agents->state[index];
	agent.sugar_level = agents->sugar_level[index];
	agent.metabolism = agents->metabolism[index];
	agent.env_sugar_level = agents->env_sugar_level[index];

	//FLAME function call
	metabolise_and_growback(&agent);
	
	

	//AoS to SoA - xmachine_memory_metabolise_and_growback Coalesced memory write (ignore arrays)
	agents->location_id[index] = agent.location_id;
	agents->agent_id[index] = agent.agent_id;
	agents->state[index] = agent.state;
	agents->sugar_level[index] = agent.sugar_level;
	agents->metabolism[index] = agent.metabolism;
	agents->env_sugar_level[index] = agent.env_sugar_level;
}

/**
 *
 */
__global__ void GPUFLAME_output_cell_state(xmachine_memory_agent_list* agents, xmachine_message_cell_state_list* cell_state_messages){
	
	
	//discrete agent: index is position in 2D agent grid
	int width = (blockDim.x * gridDim.x);
	int2 global_position;
	global_position.x = (blockIdx.x * blockDim.x) + threadIdx.x;
	global_position.y = (blockIdx.y * blockDim.y) + threadIdx.y;
	int index = global_position.x + (global_position.y * width);
	

	//SoA to AoS - xmachine_memory_output_cell_state Coalesced memory read (arrays point to first item for agent index)
	xmachine_memory_agent agent;
	agent.location_id = agents->location_id[index];
	agent.agent_id = agents->agent_id[index];
	agent.state = agents->state[index];
	agent.sugar_level = agents->sugar_level[index];
	agent.metabolism = agents->metabolism[index];
	agent.env_sugar_level = agents->env_sugar_level[index];

	//FLAME function call
	output_cell_state(&agent, cell_state_messages	);
	
	

	//AoS to SoA - xmachine_memory_output_cell_state Coalesced memory write (ignore arrays)
	agents->location_id[index] = agent.location_id;
	agents->agent_id[index] = agent.agent_id;
	agents->state[index] = agent.state;
	agents->sugar_level[index] = agent.sugar_level;
	agents->metabolism[index] = agent.metabolism;
	agents->env_sugar_level[index] = agent.env_sugar_level;
}

/**
 *
 */
__global__ void GPUFLAME_movement_request(xmachine_memory_agent_list* agents, xmachine_message_cell_state_list* cell_state_messages, xmachine_message_movement_request_list* movement_request_messages){
	
	
	//discrete agent: index is position in 2D agent grid
	int width = (blockDim.x * gridDim.x);
	int2 global_position;
	global_position.x = (blockIdx.x * blockDim.x) + threadIdx.x;
	global_position.y = (blockIdx.y * blockDim.y) + threadIdx.y;
	int index = global_position.x + (global_position.y * width);
	

	//SoA to AoS - xmachine_memory_movement_request Coalesced memory read (arrays point to first item for agent index)
	xmachine_memory_agent agent;
	agent.location_id = agents->location_id[index];
	agent.agent_id = agents->agent_id[index];
	agent.state = agents->state[index];
	agent.sugar_level = agents->sugar_level[index];
	agent.metabolism = agents->metabolism[index];
	agent.env_sugar_level = agents->env_sugar_level[index];

	//FLAME function call
	movement_request(&agent, cell_state_messages, movement_request_messages	);
	
	

	//AoS to SoA - xmachine_memory_movement_request Coalesced memory write (ignore arrays)
	agents->location_id[index] = agent.location_id;
	agents->agent_id[index] = agent.agent_id;
	agents->state[index] = agent.state;
	agents->sugar_level[index] = agent.sugar_level;
	agents->metabolism[index] = agent.metabolism;
	agents->env_sugar_level[index] = agent.env_sugar_level;
}

/**
 *
 */
__global__ void GPUFLAME_movement_response(xmachine_memory_agent_list* agents, xmachine_message_movement_request_list* movement_request_messages, xmachine_message_movement_response_list* movement_response_messages, RNG_rand48* rand48){
	
	
	//discrete agent: index is position in 2D agent grid
	int width = (blockDim.x * gridDim.x);
	int2 global_position;
	global_position.x = (blockIdx.x * blockDim.x) + threadIdx.x;
	global_position.y = (blockIdx.y * blockDim.y) + threadIdx.y;
	int index = global_position.x + (global_position.y * width);
	

	//SoA to AoS - xmachine_memory_movement_response Coalesced memory read (arrays point to first item for agent index)
	xmachine_memory_agent agent;
	agent.location_id = agents->location_id[index];
	agent.agent_id = agents->agent_id[index];
	agent.state = agents->state[index];
	agent.sugar_level = agents->sugar_level[index];
	agent.metabolism = agents->metabolism[index];
	agent.env_sugar_level = agents->env_sugar_level[index];

	//FLAME function call
	movement_response(&agent, movement_request_messages, movement_response_messages	, rand48);
	
	

	//AoS to SoA - xmachine_memory_movement_response Coalesced memory write (ignore arrays)
	agents->location_id[index] = agent.location_id;
	agents->agent_id[index] = agent.agent_id;
	agents->state[index] = agent.state;
	agents->sugar_level[index] = agent.sugar_level;
	agents->metabolism[index] = agent.metabolism;
	agents->env_sugar_level[index] = agent.env_sugar_level;
}

/**
 *
 */
__global__ void GPUFLAME_movement_transaction(xmachine_memory_agent_list* agents, xmachine_message_movement_response_list* movement_response_messages){
	
	
	//discrete agent: index is position in 2D agent grid
	int width = (blockDim.x * gridDim.x);
	int2 global_position;
	global_position.x = (blockIdx.x * blockDim.x) + threadIdx.x;
	global_position.y = (blockIdx.y * blockDim.y) + threadIdx.y;
	int index = global_position.x + (global_position.y * width);
	

	//SoA to AoS - xmachine_memory_movement_transaction Coalesced memory read (arrays point to first item for agent index)
	xmachine_memory_agent agent;
	agent.location_id = agents->location_id[index];
	agent.agent_id = agents->agent_id[index];
	agent.state = agents->state[index];
	agent.sugar_level = agents->sugar_level[index];
	agent.metabolism = agents->metabolism[index];
	agent.env_sugar_level = agents->env_sugar_level[index];

	//FLAME function call
	movement_transaction(&agent, movement_response_messages);
	
	

	//AoS to SoA - xmachine_memory_movement_transaction Coalesced memory write (ignore arrays)
	agents->location_id[index] = agent.location_id;
	agents->agent_id[index] = agent.agent_id;
	agents->state[index] = agent.state;
	agents->sugar_level[index] = agent.sugar_level;
	agents->metabolism[index] = agent.metabolism;
	agents->env_sugar_level[index] = agent.env_sugar_level;
}

	
	
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/* Rand48 functions */

__device__ static uint2 RNG_rand48_iterate_single(uint2 Xn, uint2 A, uint2 C)
{
	unsigned int R0, R1;

	// low 24-bit multiplication
	const unsigned int lo00 = __umul24(Xn.x, A.x);
	const unsigned int hi00 = __umulhi(Xn.x, A.x);

	// 24bit distribution of 32bit multiplication results
	R0 = (lo00 & 0xFFFFFF);
	R1 = (lo00 >> 24) | (hi00 << 8);

	R0 += C.x; R1 += C.y;

	// transfer overflows
	R1 += (R0 >> 24);
	R0 &= 0xFFFFFF;

	// cross-terms, low/hi 24-bit multiplication
	R1 += __umul24(Xn.y, A.x);
	R1 += __umul24(Xn.x, A.y);

	R1 &= 0xFFFFFF;

	return make_uint2(R0, R1);
}

//Templated function
template <int AGENT_TYPE>
__device__ float rnd(RNG_rand48* rand48){

	int index;
	
	//calculate the agents index in global agent list
	if (AGENT_TYPE == DISCRETE_2D){
		int width = (blockDim.x * gridDim.x);
		int2 global_position;
		global_position.x = (blockIdx.x * blockDim.x) + threadIdx.x;
		global_position.y = (blockIdx.y * blockDim.y) + threadIdx.y;
		index = global_position.x + (global_position.y * width);
	}else//AGENT_TYPE == CONTINOUS
		index = threadIdx.x + blockIdx.x*blockDim.x;

	uint2 state = rand48->seeds[index];
	uint2 A = rand48->A;
	uint2 C = rand48->C;

	int rand = ( state.x >> 17 ) | ( state.y << 7);

	// this actually iterates the RNG
	state = RNG_rand48_iterate_single(state, A, C);

	rand48->seeds[index] = state;

	return (float)rand/2147483647;
}

__device__ float rnd(RNG_rand48* rand48){
	return rnd<DISCRETE_2D>(rand48);
}

#endif //_FLAMEGPU_KERNELS_H_
