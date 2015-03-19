EV3
===

This is a library for controlling a [Lego Mindstorms EV3][ev3-mindstorms] robot
running [ev3dev][ev3dev]. With ev3dev, it is possible to run a full Debian Linux
distribution. Starting the BEAM still takes a bit of time but apart from that,
there is no problem running some Elixir or Erlang on the EV3 brick.

Motors
------

Motors of type tacho can be controlled by the following module:

* [Motor](lib/motor.ex)

Sensors
-------

Modules for the following sensors have been implemented:

* [Color Sensor](lib/color_sensor.ex)
* [Infrared Sensor](lib/infrared_sensor.ex)
* [Touch Sensor](lib/touch_sensor.ex)

How to get going for the hackathon
----------------------------------

* Pair the EV3 brick with your computer
* Connect to the computer _from the EV3 brick_
* Use SSH to connect
  - You can see the IP address on the brick
  - Username should be `jyzr`
  - The password is `elixir`

Suggested workflow
------------------

1. Start the Elixir shell on the brick  
   Command: `iex -pa ~/ev3/_build/dev/lib/ev3/ebin/`
2. Make changes to source files on your laptop
3. Compile them on your laptop by running `mix` (no arguments)
4. Sync the files to the brick with `rsync`  
   Command: `rsync -r --delete . jyzr@ev3dev:~/ev3`
5. Reload the modules in the Elixir shell
   Command: `EV3.reload_modules`

Skeleton
--------

Have a look at [LineFollower](lib/line_follower/line_follower.ex) which could be
a good start for this task.


<!-- Links -->

[ev3-mindstorms]: http://mindstorms.lego.com
[ev3dev]: http://www.ev3dev.org/
