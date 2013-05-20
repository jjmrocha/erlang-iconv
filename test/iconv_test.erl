-module(iconv_test).

-include_lib("eunit/include/eunit.hrl").

%%%========== Test collection ============================================
iconv_test_() ->
    {setup,
     fun () -> {ok,_} = iconv:start() end,
     fun(_) -> iconv:stop() end,
     [
      {"Convert from latin-1 to utf-8", fun latin1_to_utf8/0}
      , {"Convert from utf-8 to latin-1 ", fun utf8_to_latin1/0}
      , {"Big test", fun bigtest/0}
      , {"Bad-input test", fun errortest/0}
      , [{"Round-trip test "++CS++"->utf8->"++CS, fun() -> roundtrip(CS) end}
         || CS <- ["latin1",
                   "ISO-8859-1",
                   "ISO-8859-2",
                   "ISO-8859-3",
                   "ISO-8859-4",
                   "ISO-8859-5",
                   "ISO-8859-6",
                   "ISO-8859-7",
                   "ISO-8859-8",
                   "ISO-8859-9",
                   "ISO-8859-10",
                   "ISO-8859-11",
                   "ISO-8859-13",
                   "ISO-8859-14",
                   "ISO-8859-15",
                   "ISO-8859-16"]]
     ]}.

-ifdef(WITH_LEAK_TEST).
leak_test_() ->
     {setup,
      fun () -> {ok,_} = iconv:start() end,
      fun(_) -> iconv:stop() end,
      {timeout, 120,
       fun leaktest/0}}.
-endif.

%%%============================================================

test_strings() ->
    Latin1Characters = lists:seq(0,255),
    [%% Basics:
     "", "Hello, World!",
     %% Non-ASCII characters:
     "Blåbærgrød",
     "test æøå",
     "æøåÅØÆ",
     [128,255]] ++
        %% All one-character and two-character strings:
        [[X] || X <- Latin1Characters] ++
        [[X,Y] || X <- Latin1Characters, Y <- Latin1Characters] ++
        %% Random input:
        [crypto:rand_bytes(X) || X <- lists:seq(1,200)].

latin1_to_utf8() ->
    {ok, CD} = iconv:open("utf-8", "ISO-8859-1"),
    [latin1_to_utf8(CD, X) || X <- test_strings()],
    iconv:close(CD).

latin1_to_utf8(CD, S) ->
    In = list_to_binary(S),
    Out = unicode:characters_to_binary(S, latin1),
    ?assertEqual({ok, Out}, iconv:conv(CD, In)).


utf8_to_latin1() ->
    {ok, CD} = iconv:open("ISO-8859-1", "utf-8"),
    [utf8_to_latin1(CD, X) || X <- test_strings()],
    iconv:close(CD).

utf8_to_latin1(CD, S) ->
    In = unicode:characters_to_binary(S, latin1),
    Out = list_to_binary(S),
    ?assertEqual({ok, Out}, iconv:conv(CD, In)).

roundtrip(CS) ->
    Bytes = lists:seq(0,255),
    TestStrings =
        %% All zero-, one-, and two-byte sequences:
        [<<>>] ++
        [<<X>> || X <- Bytes] ++
        [<<X,Y>> || X <- Bytes, Y <- Bytes] ++
        %% Random input:
        [crypto:rand_bytes(X) || X <- lists:seq(1,200)],

    io:format(user, "using ~p test strings\n", [length(TestStrings)]),
    {ok, CD1} = iconv:open("utf-8", CS),
    {ok, CD2} = iconv:open(CS, "utf-8"),
    [roundtrip(CD1, CD2, X) || X <- TestStrings],
    iconv:close(CD1),
    iconv:close(CD2).

roundtrip(CD1, CD2, In) ->
    {ok, Tmp} = iconv:conv(CD1, In),
    ?assertEqual({ok, In}, iconv:conv(CD2, Tmp)).

bigtest() ->
    {ok, CD} = iconv:open("latin1", "utf-8"),
    [begin
         In = list_to_binary(string:copies("x",100*N)),
         {ok,Out} = iconv:conv(CD, In),
         %% io:format(user, "DB| ~w~n vs ~w~n", [In, iconv:conv(CD, In)]),
         ?assertMatch({N,X,X}, {N,byte_size(In), byte_size(Out)}),
         ?assertMatch({N,{ok,In}}, {N,iconv:conv(CD, In)})
     end
     || N <- lists:seq(655,1000)],
    iconv:close(CD).

errortest() ->
    {ok, CD} = iconv:open("ISO-8859-1", "utf-8"),
    ?assertEqual({ok, <<>>}, iconv:conv(CD, <<>>)),
    ?assertEqual({error, eilseq}, iconv:conv(CD, <<2#10000000>>)),
    ?assertEqual({error, einval}, iconv:conv(CD, <<2#11100000>>)),
    ?assertEqual({error, einval}, iconv:conv(CD, <<2#11100000, 2#10000000>>)),
    iconv:close(CD).

leaktest() ->
    In = list_to_binary(string:copies("x",60000)),
    {ok, CD} = iconv:open("latin1", "utf-8"),
    erlang:display(erlang:memory()),
    [begin
         ?assertMatch({error,eilseq}, iconv:conv(CD, <<In/binary, 16#80>>)),
         ?assertMatch({error,einval}, iconv:conv(CD, <<In/binary, 16#E0>>))
         %% timer:sleep(1)
     end
     || _ <- lists:seq(1,600000)],
    erlang:display(erlang:memory()),
    iconv:close(CD).
