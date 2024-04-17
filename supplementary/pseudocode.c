// Rough pseudocode of the webassembly text in C-syntax.
// Please note that this file isn't meant for running and won't compile.
// Only for understanding purposes. The variable/function names between the two
// might not match fully, but are however relevant.

typedef int i32;
typedef unsigned int u32;
typedef unsigned char u8;
typedef unsigned char bool;
typedef double f64;

#define false 0
#define true  1

#define EXPORT(func) // dummy export
#define START(func)  // dummy start

const u32 GRID_WIDTH  = 10;
const u32 GRID_HEIGHT = 20;

// The grid only accomodates the settled squares, but not the squares that belong to a falling piece.
const u32 GRID_TOPZONE      = 4; // Buffer zone at the top of the grid, this also where new pieces spawn
const u32 GRID_HEIGHT_TOTAL = GRID_HEIGHT + GRID_TOPZONE;
const u32 GRID_AREA         = GRID_WIDTH  * GRID_HEIGHT_TOTAL;

// The "framebuffer" (also called "drawboard" throughout the code), where all settled squares and falling piece squares reside.
// Only the visible portion belongs to this region, so the topzone isn't a part of it.
// The WASM code "renders" to this buffer, and JS code will read from it and perform the final draw (presentation)
const u32 FBUFFER_WIDTH  = GRID_WIDTH;
const u32 FBUFFER_HEIGHT = GRID_HEIGHT;
const u32 FBUFFER_AREA   = FBUFFER_WIDTH * FBUFFER_HEIGHT;

// Area where to render the piece coming next, also read by JS code for presentation
const u32 UPNEXT_AREA = 16; // 4 * 4

const u8* gridPtr      = 0; // The zero here is dummy value, actual grid might start from anywhere
const u8* drawboardPtr = gridPtr      + GRID_AREA;
const u8* upnextPtr    = drawboardPtr + FBUFFER_AREA;

// Each entry in this look-up table contains data that describes each piece's
// shape, color palette index, and the next piece index (for rotation)
// The shape is defined by four 4-bit relative coordinates of each four of the squares in a piece.
// The coordinates can further be divided into y and x values, each 2 bits (sufficient for pieces up to 4 units in width and height)
// The next piece index and color palette index are both 8-bit integers each.
// type Coord = [ y : u2 ][ x : u2 ] # 4 bits (2 bits * 2 = 4 bits)
// type CoordData = [ b1 : Coord ][ b2 : Coord ][ b3 : Coord ][ b4 : Coord ] # 16 bits (4 bits * 4 = 16 bits)
// format(u32): [ colorIndex: u8 ][ nextPiece: u8 ][ coords : CoordData ] # 32 bits (8 bits + 8 bits + 16 bits = 32 bits)
const u32 TETRIS_PIECE_TABLE[19] = {
    0x010189ab,
    0x010026ae,
    0x0202569a,
    0x0304456a,
    0x03051589,
    0x03060456,
    0x03031259,
    0x04084568,
    0x04090159,
    0x040a2456,
    0x0407159a,
    0x050c5689,
    0x050b156a,
    0x060e4569,
    0x060f1459,
    0x06101456,
    0x060d1569,
    0x0712459a,
    0x07112569
};

bool gameOver    = false;
u32 score        = 0;
i32 posX         = 0;
i32 posY         = 0;
u32 currentPiece = 0x0202569a; // anything would work as this will be replaced anyway at the start
u32 nextPiece    = 0x0202569a; // anything would work as this will be replaced anyway at the start

f64 randf64();
f64 floor(f64 val);

void onDraw(u8* drawboardPtr, u8* upnextPtr, u32 score, bool gameOver); // draw callback

void startRoutine() {
    spawnNew();
    spawnNew();
}

u8 readCell(u8* base, u32 x, u32 y, u32 width) {
    const u32 index = y * width + x;
    return *(base + index);
}

void writeCell(u8* base, u32 x, u32 y, u32 width, u8 value) {
    const u32 index = y * width + x;
    *(base + index) = value;
}

// Check if a position for a given x, y values is blocked (by wall or being occupied by other squares)
bool isCellBlocked(i32 x, i32 y) {
    // left wall boundary check
    if(x < 0) return true;

    // right wall boundary check
    if(x >= (i32)GRID_WIDTH) return true;

    // floor boundary check
    if(y >= (i32)GRID_HEIGHT_TOTAL) return true;

    const u8 occupancy = readCell(gridPtr, x, y, GRID_WIDTH);

    // occupancy check
    if(occupancy == 0) {
        return false;
    } else {
        return true;
    }
}

// Just like isCellBlocked but for a whole piece (4 squares)
bool isMoveable(i32 x, i32 y, u32 pieceData) {
    i32 bx;
    i32 by;

    bx = ((pieceData >> 0) & 0b11) + x;
    by = ((pieceData >> 2) & 0b11) + y;
    if(isCellBlocked(bx, by)) return false;

    bx = ((pieceData >> 4) & 0b11) + x;
    by = ((pieceData >> 6) & 0b11) + y;
    if(isCellBlocked(bx, by)) return false;

    bx = ((pieceData >>  8) & 0b11) + x;
    by = ((pieceData >> 10) & 0b11) + y;
    if(isCellBlocked(bx, by)) return false;

    bx = ((pieceData >> 12) & 0b11) + x;
    by = ((pieceData >> 14) & 0b11) + y;
    if(isCellBlocked(bx, by)) return false;

    return true;
}

// Place all squares of a piece on the main grid
void settlePiece(i32 x, i32 y, u32 pieceData) {
    const u8 colorIndex = pieceData >> 24;

    i32 bx;
    i32 by;

    bx = ((pieceData >> 0) & 0b11) + x;
    by = ((pieceData >> 2) & 0b11) + y;
    writeCell(gridPtr, bx, by, GRID_WIDTH, colorIndex);

    bx = ((pieceData >> 4) & 0b11) + x;
    by = ((pieceData >> 6) & 0b11) + y;
    writeCell(gridPtr, bx, by, GRID_WIDTH, colorIndex);

    bx = ((pieceData >>  8) & 0b11) + x;
    by = ((pieceData >> 10) & 0b11) + y;
    writeCell(gridPtr, bx, by, GRID_WIDTH, colorIndex);

    bx = ((pieceData >> 12) & 0b11) + x;
    by = ((pieceData >> 14) & 0b11) + y;
    writeCell(gridPtr, bx, by, GRID_WIDTH, colorIndex);
}

// used to check if a row is full or not
bool isAnyZero(u8* start, u32 len) {
    const u8* end = start + len;
    while(start < end) {
        if(*start == 0) {
            return true;
        }
        start++;
    }
    return false;
}

// perform cleaning of the grid
// this is done by looping over all rows from bottom to top
// the rows with empty cells are kept and the rest are skipped
// lastly the skipped amount of rows are filled with zeroes
// the amount of skipped/filled rows correspond to the score increase
u32 performClear() {
    u8* srcPtr = gridPtr + ((GRID_HEIGHT_TOTAL - 1) * GRID_WIDTH);
    u8* endPtr = gridPtr + (GRID_TOPZONE * GRID_WIDTH);
    u8* dstPtr = srcPtr;
    u32 count  = 0; // number of lines cleared AKA score increase

    u32 fillSize;

    while(srcPtr >= endPtr) {
        if(isAnyZero(srcPtr, GRID_WIDTH)) {
            // this line has empty cells, so it needs to be kept
            memcpy(dstPtr, srcPtr, GRID_WIDTH);
            dstPtr -= GRID_WIDTH;
        } else {
            // this line is full, so it can be cleared AKA not kept
            count++;
        }
        srcPtr -= GRID_WIDTH;
    }

    fillSize = dstPtr + GRID_WIDTH - gridPtr;

    memset(gridPtr, 0, fillSize);

    return count;
}

// place a square on the drawboard, by using its position on the main grid
// ignore the square if it is outside of the drawboard (being in the topzone)
void placeOnDrawboard(i32 bx, i32 by, u8 colorIndex) {
    if(by >= (i32)GRID_TOPZONE) {
        by -= (i32)GRID_TOPZONE;
        writeCell(drawboardPtr, bx, by, GRID_WIDTH, colorIndex);
    }
}

// calls placeOnDrawboard for all squares of a piece
void genDrawboard() {
    const u8* gridVisiblePtr = gridPtr + (GRID_TOPZONE * GRID_WIDTH);
    const u8 colorIndex = currentPiece >> 24;

    i32 bx;
    i32 by;

    memcpy(drawboardPtr, gridVisiblePtr, FBUFFER_AREA);

    bx = ((currentPiece >> 0) & 0b11) + posX;
    by = ((currentPiece >> 2) & 0b11) + posY;
    placeOnDrawboard(bx, by, colorIndex);

    bx = ((currentPiece >> 4) & 0b11) + posX;
    by = ((currentPiece >> 6) & 0b11) + posY;
    placeOnDrawboard(bx, by, colorIndex);

    bx = ((currentPiece >>  8) & 0b11) + posX;
    by = ((currentPiece >> 10) & 0b11) + posY;
    placeOnDrawboard(bx, by, colorIndex);

    bx = ((currentPiece >> 12) & 0b11) + posX;
    by = ((currentPiece >> 14) & 0b11) + posY;
    placeOnDrawboard(bx, by, colorIndex);

    onDraw(drawboardPtr, upnextPtr, score, gameOver);
}

// put the next piece on the upnext area
void genUpnext(u32 upnext) {
    const u8 colorIndex = upnext >> 24;

    i32 bx;
    i32 by;

    memset(upnextPtr, 0, UPNEXT_AREA);

    bx = (upnext >> 0) & 0b11;
    by = (upnext >> 2) & 0b11;
    writeCell(upnextPtr, bx, by, 4, colorIndex);

    bx = (upnext >> 4) & 0b11;
    by = (upnext >> 6) & 0b11;
    writeCell(upnextPtr, bx, by, 4, colorIndex);

    bx = (upnext >>  8) & 0b11;
    by = (upnext >> 10) & 0b11;
    writeCell(upnextPtr, bx, by, 4, colorIndex);

    bx = (upnext >> 12) & 0b11;
    by = (upnext >> 14) & 0b11;
    writeCell(upnextPtr, bx, by, 4, colorIndex);
}

// spawns a new piece, done by:
// choosing a random index and picking from the tetris piece table
// and setting the piece's position (random x, zero y)
void spawnNew() {
    const u32 randIndex = (u32)floor(randf64() * 19.0);
    const u32 randX     = (u32)floor(randf64() * (f64)(GRID_WIDTH - 4));

    currentPiece = nextPiece;
    nextPiece    = TETRIS_PIECE_TABLE[randIndex];
    posX         = randX;
    posY         = 0;
    genUpnext(nextPiece);
}

// move the current piece left if not blocked
void moveLeft() {
    if(!gameOver) {
        const i32 newX = posX - 1;
        if(isMoveable(newX, posY, currentPiece)) {
            posX = newX;
        }
    }
    genDrawboard();
}

// move the current piece right if not blocked
void moveRight() {
    if(!gameOver) {
        const i32 newX = posX + 1;
        if(isMoveable(newX, posY, currentPiece)) {
            posX = newX;
        }
    }
    genDrawboard();
}

// rotate the current piece if not blocked
void rotate() {
    if(!gameOver) {
        const u8 nextIndex = ((currentPiece >> 16) & 0xFF);
        const u32 newPiece = TETRIS_PIECE_TABLE[nextIndex];
        if(isMoveable(posX, posY, newPiece)) {
            currentPiece = newPiece;
        }
    }
    genDrawboard();
}

// move the current piece down if not blocked
// if blocked, check if the piece is in the top zone
// if yes, announce game over
// otherwise, settle the piece, perform a clear and spawn a new one
void moveDown() {
    if(!gameOver) {
        const i32 newY = posY + 1;
        if(isMoveable(posX, newY, currentPiece)) {
            posY = newY;
        } else {
            if(posY < (i32)GRID_TOPZONE) {
                // withtin top zone, game over
                gameOver = true;
            } else {
                settlePiece(posX, posY, currentPiece);
                score += performClear();
                spawnNew();
            }
        }
    }
    genDrawboard();
}

// reset the game
void reset() {
    gameOver = false;
    score = 0;
    spawnNew();

    memset(gridPtr, 0, GRID_AREA);
    memset(drawboardPtr, 0, FBUFFER_AREA);
    genDrawboard();
}

EXPORT(moveLeft);
EXPORT(moveRight);
EXPORT(rotate);
EXPORT(moveDown);
EXPORT(reset);
START(startRoutine);