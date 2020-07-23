#!/bin/bash

source /common.sh
source /agent-functions.sh

wait $(run_agent_stage $@)