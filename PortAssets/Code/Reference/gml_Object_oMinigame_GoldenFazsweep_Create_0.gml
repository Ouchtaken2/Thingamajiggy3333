FSEHoldActive = false;
FSEHoldTile = -1;
FSEPreviewTile = -1;
FSEDragOccurred = false;
FSEHoldStartMs = 0;
Initialize = true;
TilesCleared = 0;
BoardWidth = 10;
BoardHeight = 8;
TileSize = 16;
Mines = 10;

if (object_index == oMinigame_GoldenFazsweep)
{
    BoardWidth = 20;
    BoardHeight = 16;
    TileSize = 8;
    Mines = 50;
}

BoardSize = BoardWidth * BoardHeight;
global.MinigameSurface = -1;

function get_tile_type(arg0, arg1)
{
    if (arg0 < 0 || arg0 > (BoardWidth - 1) || arg1 < 0 || arg1 > (BoardHeight - 1))
        return -1;
    else
        return TileGrid[(arg1 * BoardWidth) + arg0];
}

function clear_surrounding_tiles(arg0, arg1)
{
    if (arg0 < 0 || arg0 >= BoardWidth || arg1 < 0 || arg1 >= BoardHeight)
        return -1;
    
    var StartIndex = (arg1 * BoardWidth) + arg0;
    
    if (TileGrid[StartIndex] != 0 || (TileCovers[StartIndex] != 0 && TileCovers[StartIndex] != 1))
        return -1;
    
    TileCovers[StartIndex] = 0;
    var Pending = [StartIndex];
    
    while (array_length(Pending) > 0)
    {
        var CurrentIndex = array_pop(Pending);
        var CenterX = CurrentIndex % BoardWidth;
        var CenterY = floor(CurrentIndex / BoardWidth);
        
        for (var DeltaY = -1; DeltaY <= 1; DeltaY++)
        {
            for (var DeltaX = -1; DeltaX <= 1; DeltaX++)
            {
                if (DeltaX == 0 && DeltaY == 0)
                    continue;
                
                var NeighborX = CenterX + DeltaX;
                var NeighborY = CenterY + DeltaY;
                
                if (NeighborX < 0 || NeighborX >= BoardWidth || NeighborY < 0 || NeighborY >= BoardHeight)
                    continue;
                
                var NeighborIndex = (NeighborY * BoardWidth) + NeighborX;
                
                if (TileCovers[NeighborIndex] != 1 || TileGrid[NeighborIndex] == 9)
                    continue;
                
                TileCovers[NeighborIndex] = 0;
                
                if (TileGrid[NeighborIndex] == 0)
                    array_push(Pending, NeighborIndex);
            }
        }
    }
    
    return 0;
}

function fse_reveal_tile(arg0, arg1)
{
    if (arg0 < 0 || arg0 >= BoardWidth || arg1 < 0 || arg1 >= BoardHeight)
        return false;
    
    var RevealIndex = (arg1 * BoardWidth) + arg0;
    
    if (TileCovers[RevealIndex] != 1)
        return false;
    
    TileCovers[RevealIndex] = 0;
    
    if (TileGrid[RevealIndex] == 9)
        return true;
    
    if (TileGrid[RevealIndex] == 0)
        clear_surrounding_tiles(arg0, arg1);
    
    return false;
}

function fse_chord_neighbors(arg0, arg1)
{
    var Result = 
    {
        triggered: false,
        mine_hit: false
    };
    
    if (arg0 < 0 || arg0 >= BoardWidth || arg1 < 0 || arg1 >= BoardHeight)
        return Result;
    
    var CenterIndex = (arg1 * BoardWidth) + arg0;
    var Number = TileGrid[CenterIndex];
    
    if (TileCovers[CenterIndex] != 0 || Number < 1 || Number > 8)
        return Result;
    
    var AdjacentFlags = 0;
    var Candidates = [];
    
    for (var DeltaY = -1; DeltaY <= 1; DeltaY++)
    {
        for (var DeltaX = -1; DeltaX <= 1; DeltaX++)
        {
            if (DeltaX == 0 && DeltaY == 0)
                continue;
            
            var NeighborX = arg0 + DeltaX;
            var NeighborY = arg1 + DeltaY;
            
            if (NeighborX < 0 || NeighborX >= BoardWidth || NeighborY < 0 || NeighborY >= BoardHeight)
                continue;
            
            var NeighborIndex = (NeighborY * BoardWidth) + NeighborX;
            
            if (TileCovers[NeighborIndex] == 2)
                AdjacentFlags++;
            else if (TileCovers[NeighborIndex] == 1)
                array_push(Candidates, NeighborIndex);
        }
    }
    
    if (AdjacentFlags != Number || array_length(Candidates) == 0)
        return Result;
    
    Result.triggered = true;
    
    for (var N = 0; N < array_length(Candidates); N++)
    {
        var CandidateIndex = Candidates[N];
        
        if (TileCovers[CandidateIndex] != 1)
            continue;
        
        var RevealX = CandidateIndex % BoardWidth;
        var RevealY = floor(CandidateIndex / BoardWidth);
        
        if (fse_reveal_tile(RevealX, RevealY))
            Result.mine_hit = true;
    }
    
    return Result;
}

function initialize_board(arg0, arg1)
{
    repeat (Mines)
    {
        var TargetTile = irandom_range(0, BoardSize - 1);
        var _x = TargetTile % BoardWidth;
        var _y = floor(TargetTile / BoardWidth);
        
        while (TileGrid[TargetTile] != 0 || point_distance(_x, _y, arg0, arg1) < 2)
        {
            TargetTile = irandom_range(0, BoardSize - 1);
            _x = TargetTile % BoardWidth;
            _y = floor(TargetTile / BoardWidth);
        }
        
        TileGrid[TargetTile] = 9;
    }
    
    for (var Tile = 0; Tile < BoardSize; Tile++)
    {
        var _x = Tile % BoardWidth;
        var _y = floor(Tile / BoardWidth);
        
        if (TileGrid[Tile] != 9)
        {
            for (var dir = 0; dir < 360; dir += 45)
            {
                if (get_tile_type(_x + round(lengthdir_x(1, dir)), _y + round(lengthdir_y(1, dir))) == 9)
                    TileGrid[Tile]++;
            }
        }
    }
}

event_inherited();
