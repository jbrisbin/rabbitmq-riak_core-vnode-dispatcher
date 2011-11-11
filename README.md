# RabbitMQ Riak Core VNode Dispatcher

This isn't so much a reusable application as an example of how to dispatch a JSON 
document into a riak_core vnode.

There is a vnode called `hello_world_vnode` that responds with a value but the dispatcher 
doesn't actually do anything with it. If you wanted to, you could send an AMQP reply to 
the original message (assuming you set a ReplyTo in the original message).

### How do I use it?

That depends on your use case. I would start with your own riak_core application that 
already has your own vnodes configured and started in it. You would then copy out the 
`hello_world_vnode_dispatcher.erl` file and put that into your application (it's a gen_server). 
You'll want to edit the AMQP connection parameters to make them configurable (probably you'll 
pull them from a config file) and add any other helpers into your state object.

Once you have the dispatcher running inside your own OTP application, you need to send an 
AMQP message to the configured exchange, passing a JSON document as the payload. To tell the 
dispatcher which vnode to invoke, add a header to your message named `x-riak-target-vnode`. 
The value you put in there will be used as the vnode to invoke in your riak_core application. 

*NOTE:* The dispatcher actually takes the value of this header and adds "_master" to the end of it. 
This value is then used to invoke the vnode. If you use some other convention for naming your vnode 
processes, then you'll want to edit this section of the code to match how you create a vnode master 
process name.

### Running this code

To test out this code, build it by typing `make` then running the `./console.sh` script, which 
will start the Erlang console with the right parameters.