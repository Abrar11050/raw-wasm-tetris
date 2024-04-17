(module
    (import "env"  "memory"      (memory $0 1))
    (import "env"  "GRID_HEIGHT" (global $GRID_HEIGHT i32))
    (import "env"  "GRID_WIDTH"  (global $GRID_WIDTH  i32))
    (import "env"  "random"      (func $random (result f64)))
    (import "env"  "onDraw"      (func $onDraw (param i32 i32 i32 i32)))
    ;; The look-up table is loaded at the very beginning of memory (little-endian), at address 0x0.
    (data (i32.const 0) "\ab\89\01\01\ae\26\00\01\9a\56\02\02\6a\45\04\03\89\15\05\03\56\04\06\03\59\12\03\03\68\45\08\04\59\01\09\04\56\24\0a\04\9a\15\07\04\89\56\0c\05\6a\15\0b\05\69\45\0e\06\59\14\0f\06\56\14\10\06\69\15\0d\06\9a\45\12\07\69\25\11\07")

    ;; global constants, the values of the mutable ones are ought to be set in the $startRoutine function, only once
    (global $GRID_TOPZONE           i32  (i32.const 4))
    (global $GRID_HEIGHT_TOTAL (mut i32) (i32.const 0))
    (global $GRID_AREA         (mut i32) (i32.const 0))
    (global $FBUFFER_WIDTH          i32  (global.get $GRID_WIDTH))
    (global $FBUFFER_HEIGHT         i32  (global.get $GRID_HEIGHT))
    (global $FBUFFER_AREA      (mut i32) (i32.const 0))
    (global $UPNEXT_AREA            i32  (i32.const 16))
    (global $TETRIS_TABLE           i32  (i32.const 0))

    ;; global pointer constants, the values of the mutable ones are ought to be set in the $startRoutine function, only once
    (global $gridPtr                i32  (i32.const 80)) ;; Grid starts here because the mem space before that is reserved for the table
    (global $drawboardPtr      (mut i32) (i32.const 0))
    (global $upnextPtr         (mut i32) (i32.const 0))

    ;; global variables, all of them are mutable
    (global $gameOver          (mut i32) (i32.const 0))
    (global $score             (mut i32) (i32.const 0))
    (global $posX              (mut i32) (i32.const 0))
    (global $posY              (mut i32) (i32.const 0))
    (global $currentPiece      (mut i32) (i32.const 33707674)) ;; overwritten when spawnNew is called
    (global $nextPiece         (mut i32) (i32.const 33707674)) ;; overwritten when spawnNew is called

    (func $startRoutine
        ;; GRID_HEIGHT_TOTAL = GRID_HEIGHT + GRID_TOPZONE;
        global.get $GRID_HEIGHT
        global.get $GRID_TOPZONE
        i32.add
        global.set $GRID_HEIGHT_TOTAL

        ;; GRID_AREA = GRID_WIDTH * GRID_HEIGHT_TOTAL;
        global.get $GRID_WIDTH
        global.get $GRID_HEIGHT_TOTAL
        i32.mul
        global.set $GRID_AREA

        ;; FBUFFER_AREA = FBUFFER_WIDTH * FBUFFER_HEIGHT;
        global.get $FBUFFER_WIDTH
        global.get $FBUFFER_HEIGHT
        i32.mul
        global.set $FBUFFER_AREA

        ;; drawboardPtr = gridPtr + GRID_AREA;
        global.get $gridPtr
        global.get $GRID_AREA
        i32.add
        global.set $drawboardPtr

        ;; upnextPtr = drawboardPtr + FBUFFER_AREA;
        global.get $drawboardPtr
        global.get $FBUFFER_AREA
        i32.add
        global.set $upnextPtr

        call $spawnNew
        call $spawnNew
    )

    (func $readCell
        (param $basePtr i32) (param $x i32) (param $y i32) (param $width i32)
        (result i32)

        (i32.mul (local.get $y) (local.get $width))
        (i32.add (local.get $x))
        (i32.add (local.get $basePtr))
        i32.load8_u
        return
    )
    (func $writeCell
        (param $basePtr i32) (param $x i32) (param $y i32) (param $width i32) (param $value i32)

        (i32.mul (local.get $y) (local.get $width))
        (i32.add (local.get $x))
        (i32.add (local.get $basePtr))
        (i32.store8 (local.get $value))
    )
    (func $isCellBlocked
        (param $x i32) (param $y i32)
        (result i32)

        (i32.lt_s (local.get $x) (i32.const 0))
        if
            (return (i32.const 1))
        end

        (i32.ge_s (local.get $x) (global.get $GRID_WIDTH))
        if
            (return (i32.const 1))
        end

        (i32.ge_s (local.get $y) (global.get $GRID_HEIGHT_TOTAL))
        if
            (return (i32.const 1))
        end

        (call $readCell (global.get $gridPtr) (local.get $x) (local.get $y) (global.get $GRID_WIDTH))
        i32.eqz
        if
            (return (i32.const 0))
        else
            (return (i32.const 1))
        end
        unreachable ;; otherwise throws this error (error: type mismatch in implicit return, expected [i32] but got [])
    )
    (func $isMoveable
        (param $x i32) (param $y i32) (param $pieceData i32)
        (result i32)

        (local $bx i32)
        (local $by i32)

        ;; ============== [ b1 ] ==============

        (i32.shr_u (local.get $pieceData) (i32.const 0))
        (i32.and (i32.const 3))
        (i32.add (local.get $x))
        local.set $bx

        (i32.shr_u (local.get $pieceData) (i32.const 2))
        (i32.and (i32.const 3))
        (i32.add (local.get $y))
        local.set $by

        (call $isCellBlocked (local.get $bx) (local.get $by))
        if
            (return (i32.const 0))
        end

        ;; ============== [ b2 ] ==============

        (i32.shr_u (local.get $pieceData) (i32.const 4))
        (i32.and (i32.const 3))
        (i32.add (local.get $x))
        local.set $bx

        (i32.shr_u (local.get $pieceData) (i32.const 6))
        (i32.and (i32.const 3))
        (i32.add (local.get $y))
        local.set $by

        (call $isCellBlocked (local.get $bx) (local.get $by))
        if
            (return (i32.const 0))
        end

        ;; ============== [ b3 ] ==============

        (i32.shr_u (local.get $pieceData) (i32.const 8))
        (i32.and (i32.const 3))
        (i32.add (local.get $x))
        local.set $bx

        (i32.shr_u (local.get $pieceData) (i32.const 10))
        (i32.and (i32.const 3))
        (i32.add (local.get $y))
        local.set $by

        (call $isCellBlocked (local.get $bx) (local.get $by))
        if
            (return (i32.const 0))
        end

        ;; ============== [ b4 ] ==============

        (i32.shr_u (local.get $pieceData) (i32.const 12))
        (i32.and (i32.const 3))
        (i32.add (local.get $x))
        local.set $bx

        (i32.shr_u (local.get $pieceData) (i32.const 14))
        (i32.and (i32.const 3))
        (i32.add (local.get $y))
        local.set $by

        (call $isCellBlocked (local.get $bx) (local.get $by))
        if
            (return (i32.const 0))
        end

        (return (i32.const 1))
    )
    (func $settlePiece
        (param $x i32) (param $y i32) (param $pieceData i32)

        (local $bx i32)
        (local $by i32)
        (local $colorIndex i32)

        (i32.shr_u (local.get $pieceData) (i32.const 24))
        local.set $colorIndex

        ;; ============== [ b1 ] ==============

        (i32.shr_u (local.get $pieceData) (i32.const 0))
        (i32.and (i32.const 3))
        (i32.add (local.get $x))
        local.set $bx

        (i32.shr_u (local.get $pieceData) (i32.const 2))
        (i32.and (i32.const 3))
        (i32.add (local.get $y))
        local.set $by

        (call $writeCell (global.get $gridPtr) (local.get $bx) (local.get $by) (global.get $GRID_WIDTH) (local.get $colorIndex))

        ;; ============== [ b2 ] ==============

        (i32.shr_u (local.get $pieceData) (i32.const 4))
        (i32.and (i32.const 3))
        (i32.add (local.get $x))
        local.set $bx

        (i32.shr_u (local.get $pieceData) (i32.const 6))
        (i32.and (i32.const 3))
        (i32.add (local.get $y))
        local.set $by

        (call $writeCell (global.get $gridPtr) (local.get $bx) (local.get $by) (global.get $GRID_WIDTH) (local.get $colorIndex))

        ;; ============== [ b3 ] ==============

        (i32.shr_u (local.get $pieceData) (i32.const 8))
        (i32.and (i32.const 3))
        (i32.add (local.get $x))
        local.set $bx

        (i32.shr_u (local.get $pieceData) (i32.const 10))
        (i32.and (i32.const 3))
        (i32.add (local.get $y))
        local.set $by

        (call $writeCell (global.get $gridPtr) (local.get $bx) (local.get $by) (global.get $GRID_WIDTH) (local.get $colorIndex))

        ;; ============== [ b4 ] ==============

        (i32.shr_u (local.get $pieceData) (i32.const 12))
        (i32.and (i32.const 3))
        (i32.add (local.get $x))
        local.set $bx

        (i32.shr_u (local.get $pieceData) (i32.const 14))
        (i32.and (i32.const 3))
        (i32.add (local.get $y))
        local.set $by

        (call $writeCell (global.get $gridPtr) (local.get $bx) (local.get $by) (global.get $GRID_WIDTH) (local.get $colorIndex))
    )
    (func $isAnyZero
        (param $start i32) (param $len i32)
        (result i32)

        (local $end i32)

        (i32.add (local.get $start) (local.get $len))
        local.set $end

        loop $checker
            (i32.lt_u (local.get $start) (local.get $end))
            if
                (i32.load8_u (local.get $start))
                i32.eqz
                if
                    (return (i32.const 1))
                end

                (i32.add (local.get $start) (i32.const 1))
                local.set $start

                br $checker
            end
        end

        (return (i32.const 0))
    )
    (func $performClear
        (result i32)

        (local $srcPtr   i32)
        (local $endPtr   i32)
        (local $dstPtr   i32)
        (local $count    i32)
        (local $fillSize i32)

        (i32.sub (global.get $GRID_HEIGHT_TOTAL) (i32.const 1))
        (i32.mul (global.get $GRID_WIDTH))
        (i32.add (global.get $gridPtr))
        local.set $srcPtr

        (i32.mul (global.get $GRID_TOPZONE) (global.get $GRID_WIDTH))
        (i32.add (global.get $gridPtr))
        local.set $endPtr

        (local.set $dstPtr (local.get $srcPtr))

        (local.set $count (i32.const 0))

        loop $removeFilled
            (i32.ge_u (local.get $srcPtr) (local.get $endPtr))
            if
                (call $isAnyZero (local.get $srcPtr) (global.get $GRID_WIDTH))
                if
                    (memory.copy (local.get $dstPtr) (local.get $srcPtr) (global.get $GRID_WIDTH))

                    (i32.sub (local.get $dstPtr) (global.get $GRID_WIDTH))
                    local.set $dstPtr
                else
                    (i32.add (local.get $count) (i32.const 1))
                    local.set $count
                end

                (i32.sub (local.get $srcPtr) (global.get $GRID_WIDTH))
                local.set $srcPtr

                br $removeFilled
            end
        end

        (i32.sub (global.get $GRID_WIDTH) (global.get $gridPtr))
        (i32.add (local.get $dstPtr))
        local.set $fillSize

        (memory.fill (global.get $gridPtr) (i32.const 0) (local.get $fillSize))

        (return (local.get $count))
    )
    (func $placeOnDrawboard
        (param $bx i32) (param $by i32) (param $colorIndex i32)

        (i32.ge_s (local.get $by) (global.get $GRID_TOPZONE))
        if
            (i32.sub (local.get $by) (global.get $GRID_TOPZONE))
            local.set $by

            (call $writeCell
                (global.get $drawboardPtr)
                (local.get  $bx)
                (local.get  $by)
                (global.get $GRID_WIDTH)
                (local.get  $colorIndex)
            )
        end
    )

    (func $genDrawboard
        (local $gridVisiblePtr i32)
        (local $colorIndex     i32)
        (local $bx             i32)
        (local $by             i32)

        (i32.mul (global.get $GRID_TOPZONE) (global.get $GRID_WIDTH))
        (i32.add (global.get $gridPtr))
        local.set $gridVisiblePtr

        (i32.shr_u (global.get $currentPiece) (i32.const 24))
        local.set $colorIndex

        (memory.copy (global.get $drawboardPtr) (local.get $gridVisiblePtr) (global.get $FBUFFER_AREA))

        ;; ============== [ b1 ] ==============

        (i32.shr_u (global.get $currentPiece) (i32.const 0))
        (i32.and (i32.const 3))
        (i32.add (global.get $posX))
        local.set $bx

        (i32.shr_u (global.get $currentPiece) (i32.const 2))
        (i32.and (i32.const 3))
        (i32.add (global.get $posY))
        local.set $by

        (call $placeOnDrawboard (local.get $bx) (local.get $by) (local.get $colorIndex))

        ;; ============== [ b2 ] ==============

        (i32.shr_u (global.get $currentPiece) (i32.const 4))
        (i32.and (i32.const 3))
        (i32.add (global.get $posX))
        local.set $bx

        (i32.shr_u (global.get $currentPiece) (i32.const 6))
        (i32.and (i32.const 3))
        (i32.add (global.get $posY))
        local.set $by

        (call $placeOnDrawboard (local.get $bx) (local.get $by) (local.get $colorIndex))

        ;; ============== [ b3 ] ==============

        (i32.shr_u (global.get $currentPiece) (i32.const 8))
        (i32.and (i32.const 3))
        (i32.add (global.get $posX))
        local.set $bx

        (i32.shr_u (global.get $currentPiece) (i32.const 10))
        (i32.and (i32.const 3))
        (i32.add (global.get $posY))
        local.set $by

        (call $placeOnDrawboard (local.get $bx) (local.get $by) (local.get $colorIndex))

        ;; ============== [ b4 ] ==============

        (i32.shr_u (global.get $currentPiece) (i32.const 12))
        (i32.and (i32.const 3))
        (i32.add (global.get $posX))
        local.set $bx

        (i32.shr_u (global.get $currentPiece) (i32.const 14))
        (i32.and (i32.const 3))
        (i32.add (global.get $posY))
        local.set $by

        (call $placeOnDrawboard (local.get $bx) (local.get $by) (local.get $colorIndex))

        (call $onDraw
            (global.get $drawboardPtr)
            (global.get $upnextPtr)
            (global.get $score)
            (global.get $gameOver)
        )
    )
    (func $genUpnext
        (param $upnext i32)

        (local $colorIndex i32)
        (local $bx         i32)
        (local $by         i32)

        (i32.shr_u (local.get $upnext) (i32.const 24))
        local.set $colorIndex

        (memory.fill (global.get $upnextPtr) (i32.const 0) (global.get $UPNEXT_AREA))

        ;; ============== [ b1 ] ==============

        (i32.shr_u (local.get $upnext) (i32.const 0))
        (i32.and (i32.const 3))
        local.set $bx

        (i32.shr_u (local.get $upnext) (i32.const 2))
        (i32.and (i32.const 3))
        local.set $by

        (call $writeCell (global.get $upnextPtr) (local.get $bx) (local.get $by) (i32.const 4) (local.get $colorIndex))

        ;; ============== [ b2 ] ==============

        (i32.shr_u (local.get $upnext) (i32.const 4))
        (i32.and (i32.const 3))
        local.set $bx

        (i32.shr_u (local.get $upnext) (i32.const 6))
        (i32.and (i32.const 3))
        local.set $by

        (call $writeCell (global.get $upnextPtr) (local.get $bx) (local.get $by) (i32.const 4) (local.get $colorIndex))

        ;; ============== [ b3 ] ==============

        (i32.shr_u (local.get $upnext) (i32.const 8))
        (i32.and (i32.const 3))
        local.set $bx

        (i32.shr_u (local.get $upnext) (i32.const 10))
        (i32.and (i32.const 3))
        local.set $by

        (call $writeCell (global.get $upnextPtr) (local.get $bx) (local.get $by) (i32.const 4) (local.get $colorIndex))

        ;; ============== [ b4 ] ==============

        (i32.shr_u (local.get $upnext) (i32.const 12))
        (i32.and (i32.const 3))
        local.set $bx

        (i32.shr_u (local.get $upnext) (i32.const 14))
        (i32.and (i32.const 3))
        local.set $by

        (call $writeCell (global.get $upnextPtr) (local.get $bx) (local.get $by) (i32.const 4) (local.get $colorIndex))
    )
    (func $spawnNew
        (global.set $currentPiece (global.get $nextPiece))

        (global.set $posY (i32.const 0))

        (i32.sub (global.get $GRID_WIDTH) (i32.const 4))
        f64.convert_i32_u
        call $random
        f64.mul
        f64.floor
        i32.trunc_f64_u ;; random u32: [0, GRID_WIDTH - 4]
        global.set $posX

        f64.const 19
        call $random
        f64.mul
        f64.floor
        i32.trunc_f64_u ;; random u32: [0, 18]
        i32.const 4
        i32.mul
        global.get $TETRIS_TABLE
        i32.add ;; [r * 4 + TETRIS_TABLE]
        i32.load
        global.set $nextPiece

        (call $genUpnext (global.get $nextPiece))
    )
    (func $moveLeft
        (local $newX i32)

        (i32.eqz (global.get $gameOver))
        if
            (i32.sub (global.get $posX) (i32.const 1))
            local.set $newX

            (call $isMoveable (local.get $newX) (global.get $posY) (global.get $currentPiece))
            if
                (global.set $posX (local.get $newX))
            end
        end

        call $genDrawboard
    )
    (func $moveRight
        (local $newX i32)

        (i32.eqz (global.get $gameOver))
        if
            (i32.add (global.get $posX) (i32.const 1))
            local.set $newX

            (call $isMoveable (local.get $newX) (global.get $posY) (global.get $currentPiece))
            if
                (global.set $posX (local.get $newX))
            end
        end

        call $genDrawboard
    )
    (func $rotate
        (local $newPiece i32)

        (i32.eqz (global.get $gameOver))
        if
            (i32.shr_u (global.get $currentPiece) (i32.const 16))
            (i32.and (i32.const 255)) ;; index
            i32.const 4
            i32.mul
            global.get $TETRIS_TABLE
            i32.add ;; [i * 4 + TETRIS_TABLE]
            i32.load
            local.set $newPiece

            (call $isMoveable (global.get $posX) (global.get $posY) (local.get $newPiece))
            if
                (global.set $currentPiece (local.get $newPiece))
            end
        end

        call $genDrawboard
    )
    (func $moveDown
        (local $newY i32)

        (i32.eqz (global.get $gameOver))
        if
            (i32.add (global.get $posY) (i32.const 1))
            local.set $newY

            (call $isMoveable (global.get $posX) (local.get $newY) (global.get $currentPiece))
            if
                (global.set $posY (local.get $newY))
            else
                (i32.lt_s (global.get $posY) (global.get $GRID_TOPZONE))
                if
                    (global.set $gameOver (i32.const 1))
                else
                    (call $settlePiece (global.get $posX) (global.get $posY) (global.get $currentPiece))

                    (i32.add (call $performClear) (global.get $score))
                    global.set $score

                    call $spawnNew
                end
            end
        end

        call $genDrawboard
    )
    (func $reset
        (global.set $gameOver (i32.const 0))

        (global.set $score (i32.const 0))

        call $spawnNew

        (memory.fill (global.get $gridPtr) (i32.const 0) (global.get $GRID_AREA))

        (memory.fill (global.get $drawboardPtr) (i32.const 0) (global.get $FBUFFER_AREA))

        call $genDrawboard
    )
    
    (export "moveLeft"  (func $moveLeft))
    (export "moveRight" (func $moveRight))
    (export "moveDown"  (func $moveDown))
    (export "rotate"    (func $rotate))
    (export "reset"     (func $reset))
    (start $startRoutine)
)