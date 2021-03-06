! Copyright (C) 2016 Zack Hixon
! see LICENSE.txt for copyright notice

USING: combinators fed.command io kernel accessors namespaces strings
    continuations prettyprint math math.parser sequences arrays
    locals sequences sorting peg.ebnf peg math.order fed.util ;
IN: fed.parse

: commandmatch ( commandstr -- command )
    {
        { "q" [ \ q ] }
        { "w" [ \ w ] }
        { "n" [ \ n ] }
        { "p" [ \ p ] }
        { "d" [ \ d ] }
        { "a" [ \ a ] }
        { "i" [ \ i ] }
        { "c" [ \ c ] }
        { "P" [ \ P ] }
        { "Q" [ \ Q ] }
        { "H" [ \ H ] }
        [
            "unknown command" { } "" { } cmderr
        ]
    } case
;

:: rangematch ( linenum buflen rangeraw -- range )
    rangeraw first :> from
    rangeraw second :> to
    rangeraw last :> comma

    ! command is not part of what we're looking at
    from to and [                             ! 1,2n
        from to > not [
            from to 2array
        ] [
            "invalid range" from to rangeerr
        ] if
    ] [                                       ! ,2n || 1,n || ,n || 1n
        comma [                               ! 1,n || ,2n
            from [                            ! 1,n
                from buflen 2array
            ] [                               ! ,2n || ,n
                to [                          ! ,2n
                    1 to 2array
                ] [                           ! ,n
                    1 buflen 2array
                ] if
            ] if
        ] [                                   ! 12n || n
            ! { from f }
            from [                            ! 12n
                { from f }
            ] [                               ! n
                { f f }
            ] if
        ] if
    ] if
;

EBNF: fedcommand
    digit     = [0-9]                              => [[ digit> ]]
    number    = (digit)+                           => [[ 10 digits>integer ]]
    range     = number?:from ","*:comma number?:to => [[ from to comma ?first 3array ]]
    letter    = [a-zA-Z]                           => [[ 1array >string ]]
    args      = (!("\n") .)*                       => [[ >string dup [ ] [ drop f ] if ]]
    ranged    = (range)?letter(args)?
    command   = (ranged|number) "\n"               => [[ first ]]
    rule      = command
;EBNF

:: parse ( buffer command -- argstr rangereal buffer cmd )
    command string>number :> num?

    buffer help?>> :> helpmsg?

    [
        command fedcommand :> ast
        { 1 1 } :> rangereal!
        ast number? [
            ! ast .
            buffer ast inboundsd [
                buffer ast >>linenum
                drop
                "" { } buffer \ nop
            ] [
                "out of bounds" ast "" buffer cmderr
            ] if
        ] [
            ! ast .
            [
                ast first :> rangeraw
                buffer linenum>> buffer totallines>> rangeraw rangematch rangereal!
                ast second :> commandstr
                commandstr commandmatch :> cmd
                ast third :> argstr
                ! rangereal .
                argstr rangereal buffer cmd execute( a r b -- b q? )
                ! [ dup linenum>> number>string print ] dip
                ! :> c?
                ! :> b2
                ! b2 linenum>> 1 b2 totallines>> clamp b2 linenum<<
                ! b2 c?
                ! b2 lines>> [ print ] each
                buffer linenum>> 1 buffer totallines>> clamp buffer linenum<<
                argstr rangereal buffer cmd
            ] [
                "?" print
                helpmsg? [ summary>> print ] [ drop ] if
                ! .
                ! buffer t
                "" { } buffer \ nop
            ] recover
        ] if
    ] [
        summary>> print
        ! drop
        "? error parsing" print
        ! .
        ! buffer t
        "" { } buffer \ nop
    ] recover
    flush
;

