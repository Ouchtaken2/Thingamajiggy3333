Paused = 0;

if (TileSize == 16)
    sprite_index = sFFS_Tiles;
else
    sprite_index = sFFS_TilesSmall;

if (room == Office)
{
    if (!global.CamUp || global.MonitorSystem != "Games")
        Paused = true;
}
else
{
    Paused = false;
}

MouseX = (global.MouseX - global.MinigameWindowX) / global.MinigameWindowScale;
MouseY = (global.MouseY - global.MinigameWindowY) / global.MinigameWindowScale;

if (!surface_exists(global.MinigameSurface))
    global.MinigameSurface = surface_create(160, 144);

surface_set_target(global.MinigameSurface);
draw_clear_alpha(c_black, 0);

if (Initialize)
{
    carnie_check();
    TileGrid = array_create(BoardSize, 0);
    TileCovers = array_create(BoardSize, 1);
    WaitForClick = true;
    Timer = 0;
    Dead = false;
    DeathFrames = 0;
    Initialize = false;
    FSEHoldActive = false;
    FSEHoldTile = -1;
    FSEPreviewTile = -1;
    FSEDragOccurred = false;
    FSEHoldStartMs = 0;
}

var TexC = 3354368;
var TexCLight = 13695200;

if (!Dead)
{
    TilesCleared = 0;
    
    for (var Tile = 0; Tile < array_length(TileGrid); Tile++)
    {
        if (TileCovers[Tile] == 0 && TileGrid[Tile] != 9 && !Dead)
            TilesCleared++;
    }
}

if (input_check_pressed(UnknownEnum.Value_0))
    Paused = !Paused;

if (room == Office)
{
    if (global.MonitorSystem != "Games" || !global.CamUp)
        Paused = true;
}

for (var Tile = 0; Tile < array_length(TileGrid); Tile++)
{
    var _x = Tile % BoardWidth;
    var _y = floor(Tile / BoardWidth);
    var XPosition = _x * TileSize;
    var YPosition = (_y * TileSize) + 16;
    
    if (Tile == 0)
    {
        var FSEHoverX = floor(MouseX / TileSize);
        var FSEHoverY = floor((MouseY - 16) / TileSize);
        var FSEHoverValid = FSEHoverX >= 0 && FSEHoverX < BoardWidth && FSEHoverY >= 0 && FSEHoverY < BoardHeight;
        var FSEHoverTile = -1;
        
        if (FSEHoverValid)
            FSEHoverTile = (FSEHoverY * BoardWidth) + FSEHoverX;
        
        if (FSEHoldActive)
        {
            if (Dead || Paused || mouse_check_button(mb_right) || (!mouse_check_button(mb_left) && !mouse_check_button_released(mb_left)))
            {
                FSEHoldActive = false;
                FSEHoldTile = -1;
                FSEPreviewTile = -1;
                FSEDragOccurred = false;
            }
            else if (mouse_check_button_released(mb_left))
            {
                var FSEHeldForMs = max(0, current_time - FSEHoldStartMs);
                
                if (FSEHoverTile != FSEHoldTile)
                    FSEDragOccurred = true;
                
                if (FSEHoverValid && (FSEDragOccurred || FSEHeldForMs <= 300))
                {
                    if (TileCovers[FSEHoverTile] == 0 && TileGrid[FSEHoverTile] >= 1 && TileGrid[FSEHoverTile] <= 8)
                    {
                        var FSEChordX = FSEHoverTile % BoardWidth;
                        var FSEChordY = floor(FSEHoverTile / BoardWidth);
                        var FSEChord = fse_chord_neighbors(FSEChordX, FSEChordY);
                        
                        if (FSEChord.triggered)
                            audio_play_sound(sfxBitCrunch, 9, false);
                        
                        if (FSEChord.mine_hit)
                        {
                            audio_play_sound(sfxBitExplosion, 99, false);
                            Dead = true;
                            moon_death_gain();
                        }
                    }
                }
                
                FSEHoldActive = false;
                FSEHoldTile = -1;
                FSEPreviewTile = -1;
                FSEDragOccurred = false;
            }
            else
            {
                if (FSEHoverTile != FSEHoldTile)
                    FSEDragOccurred = true;
                
                FSEPreviewTile = -1;
                
                if (FSEHoverValid)
                {
                    if (TileCovers[FSEHoverTile] == 0 && TileGrid[FSEHoverTile] >= 1 && TileGrid[FSEHoverTile] <= 8)
                        FSEPreviewTile = FSEHoverTile;
                }
            }
        }
        
        if (!FSEHoldActive && !Paused && !Dead && FSEHoverValid && !mouse_check_button(mb_right) && mouse_check_button_pressed(mb_left))
        {
            if (TileCovers[FSEHoverTile] == 0 && TileGrid[FSEHoverTile] >= 1 && TileGrid[FSEHoverTile] <= 8)
            {
                FSEHoldActive = true;
                FSEHoldTile = FSEHoverTile;
                FSEPreviewTile = FSEHoverTile;
                FSEDragOccurred = false;
                FSEHoldStartMs = current_time;
            }
        }
    }
    
    var CurrentTile = TileGrid[Tile];
    var TileColor = (_x + _y) % 2;
    var FSEPreviewed = false;
    
    if (FSEHoldActive && !Paused && !Dead && FSEPreviewTile >= 0 && TileCovers[Tile] == 1)
    {
        var FSEOriginX = FSEPreviewTile % BoardWidth;
        var FSEOriginY = floor(FSEPreviewTile / BoardWidth);
        
        if (abs(_x - FSEOriginX) <= 1 && abs(_y - FSEOriginY) <= 1 && (_x != FSEOriginX || _y != FSEOriginY))
            FSEPreviewed = true;
    }
    
    if (FSEPreviewed)
        draw_sprite(sprite_index, 0, XPosition, YPosition);
    else if (CurrentTile == 9)
        draw_sprite(sprite_index, CurrentTile + (floor(DeathFrames * 8) % 2), XPosition, YPosition);
    else
        draw_sprite(sprite_index, CurrentTile, XPosition, YPosition);
    
    if (MouseX >= XPosition && (XPosition + TileSize) > MouseX && MouseY >= YPosition && (YPosition + TileSize) > MouseY && !Dead && !Paused)
    {
        if (mouse_check_button_pressed(mb_left) && TileCovers[Tile] == 1)
        {
            if (WaitForClick == true)
            {
                initialize_board(_x, _y);
                WaitForClick = false;
            }
            
            var FSEHitMine = fse_reveal_tile(_x, _y);
            audio_play_sound(sfxBitCrunch, 9, false);
            
            if (FSEHitMine)
            {
                audio_play_sound(sfxBitExplosion, 99, false);
                Dead = true;
                moon_death_gain();
            }
        }
        
        if (mouse_check_button_pressed(mb_right))
        {
            if (TileCovers[Tile] == 1)
            {
                TileCovers[Tile] = 2;
                audio_play_sound(sfxBitPlace, 9, false);
            }
            else if (TileCovers[Tile] == 2)
            {
                TileCovers[Tile] = 1;
                audio_play_sound(sfxBitPlace, 9, false);
            }
        }
    }
    
    if (TileCovers[Tile] != 0 && !FSEPreviewed)
        draw_sprite(sprite_index, TileColor + 9 + (TileCovers[Tile] * 2), XPosition, YPosition);
}

var TilesLeft = BoardSize - (Mines + TilesCleared);

if (TilesLeft == 0 && !Dead)
{
    Dead = true;
    add_tokens(200);
    global.TokensPerMinigame[UnknownEnum.Value_7] += 200;
    
    if (global.HiScores[UnknownEnum.Value_7] > Timer)
        global.HiScores[UnknownEnum.Value_7] = Timer;
    
    if (global.HiScoresOverall[UnknownEnum.Value_7] > Timer)
        global.HiScoresOverall[UnknownEnum.Value_7] = Timer;
    
    get_trophy(UnknownEnum.Value_11);
}

draw_rectangle_color(0, 0, 160, 16, TexC, TexC, TexC, TexC, false);
draw_set_font(global.FontGameboy);
draw_text_color(2, 4, "Tiles: " + string(TilesLeft), TexCLight, TexCLight, TexCLight, TexCLight, 1);
draw_set_halign(fa_right);
draw_text_color(158, 4, format_as_timer(Timer), TexCLight, TexCLight, TexCLight, TexCLight, 1);
draw_set_halign(fa_left);
draw_set_font(global.FontW97Black);
surface_reset_target();

if (Dead)
    DeathFrames += 0.016666666666666666;

if (DeathFrames > 1 && TilesLeft > 0)
    TileCovers = array_create(BoardSize, 0);

if (DeathFrames > 3)
    Initialize = true;

if (!(Paused || WaitForClick || Dead))
{
    Timer += 0.016666666666666666;
    moon_passive_gain(0.1);
}

enum UnknownEnum
{
    Value_0,
    Value_7 = 7,
    Value_11 = 11
}
