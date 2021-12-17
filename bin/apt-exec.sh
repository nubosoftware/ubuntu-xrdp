#!/bin/bash

apt update > /dev/null
apt "$@"