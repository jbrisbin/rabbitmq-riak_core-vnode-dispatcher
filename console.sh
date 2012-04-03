#!/bin/bash
erl -pa ebin -pa deps/*/ebin -config hello_world -s hello_world -sname helloworld@localhost