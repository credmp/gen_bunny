-module(bunnyc_tests).

-include("gen_bunny.hrl").
-include_lib("eunit/include/eunit.hrl").

bunnyc_setup() ->
    {ok, _} = mock:mock(amqp_channel),
    {ok, _} = mock:mock(amqp_connection),
    ok.


bunnyc_stop(_) ->
    bunnyc:stop(bunnyc_test),

    mock:verify_and_stop(amqp_channel),
    mock:verify_and_stop(amqp_connection),
    ok.


connect_and_declare_expects(TestName) ->
    [{connect_fun,
      fun(direct) ->
              {ok, {dummy_conn, dummy_channel}}
      end},

     {declare_fun,
      fun(dummy_channel, N) when N =:= TestName ->
              {ok, {#'exchange.declare'{exchange = TestName},
                    #'queue.declare'{queue = TestName}}}
      end}].


stop_expects() ->
    mock:expects(amqp_channel, close,
                 fun({dummy_channel}) ->
                         true
                 end,
                 ok),

    mock:expects(amqp_connection, close,
                 fun({dummy_conn}) ->
                         true
                 end,
                 ok),
    ok.


bunnyc_test_() ->
    {setup, fun bunnyc_setup/0, fun bunnyc_stop/1,
     ?_test(
        [begin
             DummyFuns = connect_and_declare_expects(<<"bunnyc.test">>),
             stop_expects(),
             {ok, Pid} = bunnyc:start_link(bunnyc_test, direct,
                                           <<"bunnyc.test">>, DummyFuns),
             ?assertEqual(is_pid(Pid), true),
             ?assertEqual(is_process_alive(Pid), true)
         end])}.



normal_setup() ->
    {ok, _} = mock:mock(amqp_channel),
    {ok, _} = mock:mock(amqp_connection),
    {ok, _} = bunnyc:start_link(
                bunnyc_test, direct, <<"bunnyc.test">>,
                connect_and_declare_expects(<<"bunnyc.test">>)),
    stop_expects(),
    ok.


normal_stop(_) ->
    bunnyc:stop(bunnyc_test),
    mock:verify_and_stop(amqp_channel),
    mock:verify_and_stop(amqp_connection),
    ok.


publish_test_() ->
    {setup, fun normal_setup/0, fun normal_stop/1,
     ?_test(
        [begin
             mock:expects(
               amqp_channel, call,
               fun({dummy_channel, #'basic.publish'{
                      exchange = <<"bunnyc.test">>,
                      routing_key = <<"bunnyc.test">>},
                    #amqp_msg{payload=Payload}}) ->
                       Payload =:= <<"HELLO GOODBYE">>
               end,
               ok),

             ?assertEqual(ok, bunnyc:publish(
                                bunnyc_test,
                                <<"bunnyc.test">>,
                                <<"HELLO GOODBYE">>))
         end])}.


async_publish_test_() ->
    {setup, fun normal_setup/0, fun normal_stop/1,
     ?_test(
        [begin
             mock:expects(
               amqp_channel, cast,
               fun({dummy_channel, #'basic.publish'{
                      exchange = <<"bunnyc.test">>,
                      routing_key = <<"bunnyc.test">>},
                    #amqp_msg{payload=Payload}}) ->
                       Payload =:= <<"HELLO GOODBYE">>
               end,
               ok),

             ?assertEqual(ok, bunnyc:async_publish(
                                bunnyc_test,
                                <<"bunnyc.test">>,
                                <<"HELLO GOODBYE">>))
         end])}.


publish_message_test_() ->
    {setup, fun normal_setup/0, fun normal_stop/1,
     ?_test(
        [begin
             ExpectedMessage = bunny_util:set_delivery_mode(
                                 bunny_util:new_message(<<"HELLO">>),
                                 2),
             ExpectedPayload = bunny_util:get_payload(ExpectedMessage),

             mock:expects(
               amqp_channel, call,
               fun({dummy_channel, #'basic.publish'{exchange=Exchange,
                                                    routing_key=Key},
                    #amqp_msg{props=Props, payload=Payload}}) ->
                       Exchange =:= <<"bunnyc.test">>
                           andalso Key =:= <<"bunnyc.test">>
                           andalso (
                             ExpectedMessage#content.properties =:= Props)
                           andalso (ExpectedPayload =:= Payload)
               end,
               ok),
             ?assertEqual(ok, bunnyc:publish(
                                bunnyc_test,
                                <<"bunnyc.test">>,
                                ExpectedMessage))
         end])}.


async_publish_message_test_() ->
    {setup, fun normal_setup/0, fun normal_stop/1,
     ?_test(
        [begin
             ExpectedMessage = bunny_util:set_delivery_mode(
                                 bunny_util:new_message(<<"HELLO">>),
                                 2),
             ExpectedPayload = bunny_util:get_payload(ExpectedMessage),

             mock:expects(
               amqp_channel, cast,
               fun({dummy_channel, #'basic.publish'{exchange=Exchange,
                                                    routing_key=Key},
                    #amqp_msg{props=Props, payload=Payload}}) ->
                       Exchange =:= <<"bunnyc.test">>
                           andalso Key =:= <<"bunnyc.test">>
                           andalso (
                             ExpectedMessage#content.properties =:= Props)
                           andalso (
                             ExpectedPayload =:= Payload)
               end,
               ok),
             ?assertEqual(ok, bunnyc:async_publish(
                                bunnyc_test,
                                <<"bunnyc.test">>,
                                ExpectedMessage))
         end])}.


publish_mandatory_test_() ->
    {setup, fun normal_setup/0, fun normal_stop/1,
     ?_test(
        [begin
             mock:expects(
               amqp_channel, call,
               fun({dummy_channel, #'basic.publish'{
                      exchange = <<"bunnyc.test">>,
                      routing_key = <<"bunnyc.test">>,
                      mandatory = true},
                    #amqp_msg{payload=Payload}}) ->
                       Payload =:= <<"HELLO GOODBYE">>
               end,
               ok),

             ?assertEqual(ok, bunnyc:publish(
                                bunnyc_test,
                                <<"bunnyc.test">>,
                                <<"HELLO GOODBYE">>, [{mandatory, true}]))
         end])}.


async_publish_mandatory_test_() ->
    {setup, fun normal_setup/0, fun normal_stop/1,
     ?_test(
        [begin
             mock:expects(
               amqp_channel, cast,
               fun({dummy_channel, #'basic.publish'{
                      exchange = <<"bunnyc.test">>,
                      routing_key = <<"bunnyc.test">>,
                      mandatory = true},
                    #amqp_msg{payload=Payload}}) ->
                       Payload =:= <<"HELLO GOODBYE">>
               end,
               ok),

             ?assertEqual(ok, bunnyc:async_publish(
                                bunnyc_test,
                                <<"bunnyc.test">>,
                                <<"HELLO GOODBYE">>, [{mandatory, true}]))
         end])}.


get_test_() ->
    {setup, fun normal_setup/0, fun normal_stop/1,
     ?_test(
        [begin
             mock:expects(amqp_channel, call,
                          fun({dummy_channel,
                               #'basic.get'{
                                 queue= <<"bunnyc.test">>,
                                 no_ack=false}}) ->
                                  true
                          end,
                          {<<"sometag">>,
                           bunny_util:new_message(<<"somecontent">>)}),
             ?assertEqual({<<"sometag">>,
                           bunny_util:new_message(<<"somecontent">>)},
                          bunnyc:get(bunnyc_test, false))
        end])}.


get_noack_test_() ->
    {setup, fun normal_setup/0, fun normal_stop/1,
     ?_test(
        [begin
             mock:expects(amqp_channel, call,
                          fun({dummy_channel,
                               #'basic.get'{queue= <<"bunnyc.test">>,
                                            no_ack=true}}) ->
                                  true
                          end,
                          bunny_util:new_message(<<"somecontent">>)),
             ?assertEqual(bunny_util:new_message(<<"somecontent">>),
                          bunnyc:get(bunnyc_test, true))
        end])}.


ack_test_() ->
    {setup, fun normal_setup/0, fun normal_stop/1,
     ?_test(
        [begin
             mock:expects(amqp_channel, cast,
                          fun({dummy_channel, #'basic.ack'{
                                 delivery_tag= <<"sometag">>}}) ->
                                  true
                          end,
                          ok),
             ?assertEqual(ok, bunnyc:ack(bunnyc_test, <<"sometag">>))
         end])}.


%% These are mostly to placate cover.

unknown_cast_test() ->
    ?assertEqual({noreply, #bunnyc_state{}},
                 bunnyc:handle_cast(unknown_cast, #bunnyc_state{})).


unknown_info_test() ->
    ?assertEqual({noreply, #bunnyc_state{}},
                 bunnyc:handle_info(unknown_info, #bunnyc_state{})).


code_change_test() ->
    ?assertEqual({ok, #bunnyc_state{}},
                 bunnyc:code_change(ign, #bunnyc_state{}, ign)).
