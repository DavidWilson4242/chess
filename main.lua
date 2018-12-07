local circles = {} 

-- constants
local CELL_SIZE = 100
local CIRCLE_SIZE = 10
local START_TIME = 60*5
local TIME_INCREMENT = 5
local CLOCK_FONT_SIZE = 48
local CAPTURED_SIZE = 50

-- misc constants
local WIDTH = love.graphics.getWidth()
local HEIGHT = love.graphics.getHeight()
local BOARD_X = 8
local BOARD_Y = 8
local CELL_SCALE;  -- TBD after loading chess set
local CAPTURED_CELL_SCALE; -- TBD
local BOARD_SIZE = 8*CELL_SIZE
local BOARD_OFFSET_X = (WIDTH - BOARD_SIZE)/2
local BOARD_OFFSET_Y = (HEIGHT - BOARD_SIZE)/2

-- colors
local DARK_TILE_COLOR = {95/255, 206/255, 124/255}
local LIGHT_TILE_COLOR = {199/255, 224/255, 126/255}
local CIRCLE_COLOR = {142/255, 106/255, 70/255}

-- sprite data
local chess_sprites = love.graphics.newImage("sprites/chess_set.png")
local chess_width, chess_height = chess_sprites:getDimensions()
local piece_width = chess_width/6
local piece_height = chess_height/2
local background_sprite = love.graphics.newImage("sprites/background.jpg")
CELL_SCALE = CELL_SIZE/piece_width
CAPTURED_SCALE = CAPTURED_SIZE/piece_width

-- fonts
local clock_font = love.graphics.newFont(CLOCK_FONT_SIZE)

-- sounds
local sound_check = love.audio.newSource("sounds/countdown1.mp3", "static")
local sound_move = love.audio.newSource("sounds/move.mp3", "static")
local sound_capture = love.audio.newSource("sounds/capture.mp3", "static")

-- game variables
local mouse_down = false
local mouse_start_x = 0
local mouse_start_y = 0
local mouse_dx = 0
local mouse_dy = 0
local player_turn = "white"
local selected_piece = nil
local time_white = START_TIME
local time_black = START_TIME
local elapsed_white = 0
local elapsed_black = 0
local game_running = false
local white_captured = {}
local black_captured = {}

-- valid moves is a table of {cell_x, cell_y} describing valid moves
-- for the current selected piece
local valid_moves = {}

local piece_data = {
    white = {
        king   = {name = "king",   color = "white", quad = love.graphics.newQuad(piece_width*0, 0, piece_width, piece_height, chess_width, chess_height)};
        queen  = {name = "queen",  color = "white", quad = love.graphics.newQuad(piece_width*1, 0, piece_width, piece_height, chess_width, chess_height)};
        bishop = {name = "bishop", color = "white", quad = love.graphics.newQuad(piece_width*2, 0, piece_width, piece_height, chess_width, chess_height)};
        knight = {name = "knight", color = "white", quad = love.graphics.newQuad(piece_width*3, 0, piece_width, piece_height, chess_width, chess_height)};
        rook   = {name = "rook",   color = "white", quad = love.graphics.newQuad(piece_width*4, 0, piece_width, piece_height, chess_width, chess_height)};
        pawn   = {name = "pawn",   color = "white", quad = love.graphics.newQuad(piece_width*5, 0, piece_width, piece_height, chess_width, chess_height)};
    };
    black = {
        king   = {name = "king",   color = "black", quad = love.graphics.newQuad(piece_width*0, piece_height, piece_width, piece_height, chess_width, chess_height)};
        queen  = {name = "queen",  color = "black", quad = love.graphics.newQuad(piece_width*1, piece_height, piece_width, piece_height, chess_width, chess_height)};
        bishop = {name = "bishop", color = "black", quad = love.graphics.newQuad(piece_width*2, piece_height, piece_width, piece_height, chess_width, chess_height)};
        knight = {name = "knight", color = "black", quad = love.graphics.newQuad(piece_width*3, piece_height, piece_width, piece_height, chess_width, chess_height)};
        rook   = {name = "rook",   color = "black", quad = love.graphics.newQuad(piece_width*4, piece_height, piece_width, piece_height, chess_width, chess_height)};
        pawn   = {name = "pawn",   color = "black", quad = love.graphics.newQuad(piece_width*5, piece_height, piece_width, piece_height, chess_width, chess_height)};
    }
};

local board = {}

--[[
    a piece is a struct with the following data:
    {
        data = piece_data;
        x = board_x_position;
        y = board_y_position;
        ox = offset_x;
        oy = offser_y
        has_moved = piece_has_moved;
    }
]]
local function make_piece(name, color, x, y)

    local piece = {}
    piece.data = piece_data[color][name]
    piece.x = x
    piece.y = y
    piece.ox = 0
    piece.oy = 0
    piece.has_moved = false

    -- insert piece onto the board
    board[x][y] = piece

    return piece

end

local function get_cell(mouse_x, mouse_y)
    local cell_x = math.floor((mouse_x - BOARD_OFFSET_X) / CELL_SIZE) + 1
    local cell_y = math.floor((mouse_y - BOARD_OFFSET_Y) / CELL_SIZE) + 1
    return cell_x, cell_y
end

local function is_valid_cell(cell_x, cell_y)
    return cell_x >= 1 and cell_x <= 8 and cell_y >= 1 and cell_y <= 8
end

local function get_piece(cell_x, cell_y)
    if not is_valid_cell(cell_x, cell_y) then
        return nil
    end
    return board[cell_x][cell_y]
end

local function reset_board()
    board = {}
    for i = 1, BOARD_Y do
        board[i] = {}
    end

    for i = 1, 2 do
        -- i=1, initialize black. i=2, initialize white
        local y = (i == 1) and 1 or 8
        local pawn_y = (i == 1) and 2 or 7
        local color = (i == 1) and "black" or "white"
        board[1][y] = make_piece("rook", color, 1, y)
        board[2][y] = make_piece("knight", color, 2, y)
        board[3][y] = make_piece("bishop", color, 3, y)
        board[4][y] = make_piece("queen", color, 4, y)
        board[5][y] = make_piece("king", color, 5, y)
        board[6][y] = make_piece("bishop", color, 6, y)
        board[7][y] = make_piece("knight", color, 7, y)
        board[8][y] = make_piece("rook", color, 8, y)
        for j = 1, 8 do
            board[j][pawn_y] = make_piece("pawn", color, j, pawn_y)
        end
    end
end

local function get_moves_in_direction(color, distance, start_x, start_y, dx, dy)
    local valid = {}
    for i = 1, distance do
        local mx = start_x + dx*i
        local my = start_y + dy*i
        if not is_valid_cell(mx, my) then
            break
        end
        local piece = get_piece(mx, my)
        if piece then
            if piece.data.color ~= color then
                table.insert(valid, {mx, my})
            end
            break
        end
        table.insert(valid, {mx, my})
    end
    return valid
end

local function isvalid_pawn(my_piece, move_x, move_y)
    local direction = player_turn == "white" and -1 or 1
    
    if not my_piece.has_moved and my_piece.x == move_x and my_piece.y + direction*2 == move_y then
        -- attempt to make a two space move?
        if get_piece(move_x, move_y) then
            return false
        end
        return true
    end

    if my_piece.x == move_x and my_piece.y + direction == move_y then
        -- single step forward?
        if get_piece(move_x, move_y) then
            return false
        end
        return true
    end

    if my_piece.y + direction == move_y and (my_piece.x - 1 == move_x or my_piece.x + 1 == move_x) then
        -- attack diagonally?
        local piece = get_piece(move_x, move_y)
        if not piece then
            return false
        end
        -- dont allow attack to friendly color
        if piece.data.color == my_piece.data.color then
            return false
        end
        return true
    end

    return false

end

local function isvalid_rook(my_piece, move_x, move_y)
    -- just compile a list of valid moves and check if our move is in it
    local valid = {}
    
    -- {dx, dy}
    local directions = {{1, 0}, {-1, 0}, {0, 1}, {0, -1}}

    for i, v in ipairs(directions) do
        for j, k in ipairs(get_moves_in_direction(my_piece.data.color, 8, my_piece.x, my_piece.y, v[1], v[2])) do
            table.insert(valid, {k[1], k[2]})
        end
    end

    for i, v in ipairs(valid) do
        if v[1] == move_x and v[2] == move_y then
            return true
        end
    end
end

local function isvalid_knight(my_piece, move_x, move_y)
    
    --[[
        . . E . E . .
        . E . . . E .
        . . . K . . .
        . E . . . E .
        . . E . E . .
    ]]

    -- {dx, dy}
    local valid_deltas = {{-2, -1}, {-1, -2}, {1, -2}, {2, -1}, 
                          {2, 1}, {1, 2}, {-1, 2}, {-2, 1}}

    for i, v in ipairs(valid_deltas) do
        if move_x == my_piece.x + v[1] and move_y == my_piece.y + v[2] then
            local check_piece = get_piece(move_x, move_y)
            -- don't allow knight to step on friendly color
            if check_piece and check_piece.data.color == my_piece.data.color then
                return false
            end
            return true
        end
    end

    return false

end

local function isvalid_bishop(my_piece, move_x, move_y)

    -- just compile a list of valid moves and check if our move is in it
    local valid = {}
    
    -- {dx, dy}
    local directions = {{-1, 1}, {-1, -1}, {1, -1}, {1, 1}}

    for i, v in ipairs(directions) do
        for j, k in ipairs(get_moves_in_direction(my_piece.data.color, 8, my_piece.x, my_piece.y, v[1], v[2])) do
            table.insert(valid, {k[1], k[2]})
        end
    end

    for i, v in ipairs(valid) do
        if v[1] == move_x and v[2] == move_y then
            return true
        end
    end
end

local function isvalid_king(my_piece, move_x, move_y)

    -- just compile a list of valid moves and check if our move is in it
    local valid = {}
    
    -- {dx, dy}
    local directions = {{-1, 1}, {-1, -1}, {1, -1}, {1, 1},
                        {1, 0}, {-1, 0}, {0, 1}, {0, -1}}

    for i, v in ipairs(directions) do
        for j, k in ipairs(get_moves_in_direction(my_piece.data.color, 1, my_piece.x, my_piece.y, v[1], v[2])) do
            table.insert(valid, {k[1], k[2]})
        end
    end

    for i, v in ipairs(valid) do
        if v[1] == move_x and v[2] == move_y then
            return true
        end
    end
end

local function isvalid_queen(my_piece, move_x, move_y)
    
    -- just compile a list of valid moves and check if our move is in it
    local valid = {}
    
    -- {dx, dy}
    local directions = {{-1, 1}, {-1, -1}, {1, -1}, {1, 1},
                        {1, 0}, {-1, 0}, {0, 1}, {0, -1}}

    for i, v in ipairs(directions) do
        for j, k in ipairs(get_moves_in_direction(my_piece.data.color, 8, my_piece.x, my_piece.y, v[1], v[2])) do
            table.insert(valid, {k[1], k[2]})
        end
    end

    for i, v in ipairs(valid) do
        if v[1] == move_x and v[2] == move_y then
            return true
        end
    end
    
end

-- cell_x and cell_y are valid cell positions
local function make_move(cell_x, cell_y)

    local my_piece = selected_piece
    local my_x = selected_piece.x
    local my_y = selected_piece.y

    local att_piece = board[cell_x][cell_y]
    local att_x = cell_x
    local att_y = cell_y

    local function do_make_move()

        game_running = true 

        -- play sounds accordingly
        if not board[att_x][att_y] then
            sound_move:play()
        else
            sound_capture:play()
        end

        -- award time
        if player_turn == "white" then
            time_white = time_white + TIME_INCREMENT
        else
            time_black = time_black + TIME_INCREMENT
        end

        -- move the piece
        board[my_x][my_y] = nil
        my_piece.x = att_x
        my_piece.y = att_y
        if board[att_x][att_y] then
            if player_turn == "white" then
                table.insert(white_captured, board[att_x][att_y])
            else
                table.insert(black_captured, board[att_x][att_y])
            end
        end
        board[att_x][att_y] = my_piece
        my_piece.has_moved = true

        -- change turn
        player_turn = (player_turn == "white" and "black" or "white")
    end
    
    -- the function that will be used to validate each tile
    local validity_check_function = (
        my_piece.data.name == "pawn" and isvalid_pawn or
        my_piece.data.name == "rook" and isvalid_rook or
        my_piece.data.name == "knight" and isvalid_knight or
        my_piece.data.name == "bishop" and isvalid_bishop or
        my_piece.data.name == "king" and isvalid_king or
        my_piece.data.name == "queen" and isvalid_queen or nil
    )

    if validity_check_function(my_piece, att_x, att_y) then
        do_make_move()
    end
    

end

local function get_piece_from_mouse(mouse_x, mouse_y)
    local board_x = BOARD_OFFSET_X
    local board_y = BOARD_OFFSET_Y
    local board_mx = mouse_x - board_x
    local board_my = mouse_y - board_y

    -- bail if mouse isn't in bounds
    if board_mx < 0 or board_mx > BOARD_SIZE or board_my < 0 or board_my > BOARD_SIZE then
        return nil
    end
    
    -- calculate cell position
    local cell_x, cell_y = get_cell(mouse_x, mouse_y)
    
    -- this shouldn't happen, since we know the mouse is
    -- in bounds, but better safe than sorry
    if cell_x < 1 or cell_x > 8 or cell_y < 1 or cell_y > 8 then
        return nil
    end

    return board[cell_x][cell_y]

end

local function draw_board() 
    
    -- background square
    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle("fill", BOARD_OFFSET_X - 10, BOARD_OFFSET_Y - 10, BOARD_SIZE + 20, BOARD_SIZE + 20) 

    for i = 1, 8 do
        for j = 1, 8 do
            -- draw tiles
            local is_dark_tile = (i - 1 + j%2) % 2 == 0
            if is_dark_tile then
                love.graphics.setColor(DARK_TILE_COLOR[1], DARK_TILE_COLOR[2], DARK_TILE_COLOR[3], 1)
            else 
                love.graphics.setColor(LIGHT_TILE_COLOR[1], LIGHT_TILE_COLOR[2], LIGHT_TILE_COLOR[3], 1)
            end
            
            local x_pos = (i - 1)*CELL_SIZE + BOARD_OFFSET_X
            local y_pos = (j - 1)*CELL_SIZE + BOARD_OFFSET_Y

            love.graphics.rectangle("fill", x_pos, y_pos, CELL_SIZE, CELL_SIZE)

            -- draw piece
            local piece = board[i][j]
            if piece then
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.draw(chess_sprites, piece.data.quad, x_pos + piece.ox, y_pos + piece.oy, 0, CELL_SCALE)
            end
        end
    end

    -- draw circles for valid moves
    for i, v in ipairs(valid_moves) do
        local x_pos = (v.cell_x - 1)*CELL_SIZE + BOARD_OFFSET_X
        local y_pos = (v.cell_y - 1)*CELL_SIZE + BOARD_OFFSET_Y
        
        love.graphics.setColor(CIRCLE_COLOR[1], CIRCLE_COLOR[2], CIRCLE_COLOR[3], 220/255)
        love.graphics.circle("fill", x_pos + CELL_SIZE/2, y_pos + CELL_SIZE/2, CIRCLE_SIZE, CIRCLE_SIZE)
    end
    
    love.graphics.setColor(1, 1, 1, 1)
    
    -- redraw the selected piece so that it is layered
    -- on top of everything else
    if selected_piece then
        local x_pos = (selected_piece.x - 1)*CELL_SIZE + BOARD_OFFSET_X
        local y_pos = (selected_piece.y - 1)*CELL_SIZE + BOARD_OFFSET_Y
        love.graphics.draw(chess_sprites, selected_piece.data.quad, x_pos + selected_piece.ox, y_pos + selected_piece.oy, 0, CELL_SCALE)
    end

end

local function draw_clock()

    local function seconds_to_string(s)
        return string.format("%01d:%02d", math.floor(s/60), s%60)
    end

    local box_sx = 200
    local box_sy = 300
    local box_x = BOARD_OFFSET_X - box_sx - 40
    local box_y = BOARD_OFFSET_Y + (BOARD_SIZE/2) - box_sy/2
    
    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle("fill", box_x - 10, box_y - 10, box_sx + 20, box_sy + 20)
    if player_turn == "white" then
        love.graphics.setColor(DARK_TILE_COLOR[1], DARK_TILE_COLOR[2], DARK_TILE_COLOR[3])
    else 
        love.graphics.setColor(LIGHT_TILE_COLOR[1], LIGHT_TILE_COLOR[2], LIGHT_TILE_COLOR[3])
    end
    love.graphics.rectangle("fill", box_x, box_y, box_sx, box_sy/2)
    if player_turn == "white" then
        love.graphics.setColor(LIGHT_TILE_COLOR[1], LIGHT_TILE_COLOR[2], LIGHT_TILE_COLOR[3])
    else 
        love.graphics.setColor(DARK_TILE_COLOR[1], DARK_TILE_COLOR[2], DARK_TILE_COLOR[3])
    end
    love.graphics.rectangle("fill", box_x, box_y + box_sy/2, box_sx, box_sy/2)
    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle("fill", box_x, box_y + box_sy/2 - 5, box_sx, 10)
    
    love.graphics.setFont(clock_font)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(seconds_to_string(time_black), box_x + 45, box_y + box_sy/4 - CLOCK_FONT_SIZE/2, box_x)
    love.graphics.printf(seconds_to_string(time_white), box_x + 45, box_y + 3*box_sy/4 - CLOCK_FONT_SIZE/2, box_x)

end

local function draw_captured()
    
    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle("fill", BOARD_OFFSET_X - 10, BOARD_OFFSET_Y + BOARD_SIZE + 20, BOARD_SIZE + 20, 70)
    love.graphics.setColor(LIGHT_TILE_COLOR[1], LIGHT_TILE_COLOR[2], LIGHT_TILE_COLOR[3])
    love.graphics.rectangle("fill", BOARD_OFFSET_X, BOARD_OFFSET_Y + BOARD_SIZE + 30, BOARD_SIZE, 50)

    local box_x = BOARD_OFFSET_X
    local box_y = BOARD_OFFSET_Y + BOARD_SIZE + 30

    for i, v in ipairs(white_captured) do
        local x_pos = (i - 1)*CAPTURED_SIZE + box_x 
        local y_pos = box_y
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(chess_sprites, v.data.quad, x_pos, y_pos, 0, CAPTURED_SCALE)
    end

    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle("fill", BOARD_OFFSET_X - 10, BOARD_OFFSET_Y - 90, BOARD_SIZE + 20, 70)
    love.graphics.setColor(LIGHT_TILE_COLOR[1], LIGHT_TILE_COLOR[2], LIGHT_TILE_COLOR[3])
    love.graphics.rectangle("fill", BOARD_OFFSET_X, BOARD_OFFSET_Y - 80, BOARD_SIZE, 50)

    local box_x = BOARD_OFFSET_X
    local box_y = BOARD_OFFSET_Y - 80

    for i, v in ipairs(black_captured) do
        local x_pos = (i - 1)*CAPTURED_SIZE + box_x 
        local y_pos = box_y
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(chess_sprites, v.data.quad, x_pos, y_pos, 0, CAPTURED_SCALE)
    end

end

function love.load()

    math.randomseed(os.time())
    reset_board()

end

function love.update(dt)

    -- pass time
    if game_running then
        if player_turn == "white" then
            elapsed_white = elapsed_white + dt
        else
            elapsed_black = elapsed_black + dt
        end

        time_white = START_TIME - elapsed_white
        time_black = START_TIME - elapsed_black
    end

    local mx = love.mouse.getX()
    local my = love.mouse.getY()

    mouse_dx = mx - mouse_start_x
    mouse_dy = my - mouse_start_y

    if selected_piece then
        selected_piece.ox = mouse_dx
        selected_piece.oy = mouse_dy
    end

end

function love.mousepressed(x, y, b)
    if b == 1 then
        mouse_down = true
        mouse_start_x = x
        mouse_start_y = y

        local piece = get_piece_from_mouse(x, y)

        if not piece then
            return
        end
        
        -- only allow the piece to be selected if it is the player's piece
        if piece.data.color == player_turn then
            selected_piece = piece     
    
            -- find valid move cells for this piece
            local validity_check_function = (
                selected_piece.data.name == "pawn" and isvalid_pawn or
                selected_piece.data.name == "rook" and isvalid_rook or
                selected_piece.data.name == "knight" and isvalid_knight or
                selected_piece.data.name == "bishop" and isvalid_bishop or
                selected_piece.data.name == "king" and isvalid_king or
                selected_piece.data.name == "queen" and isvalid_queen or nil
            )
            valid_moves = {}
            for i = 1, 8 do
                for j = 1, 8 do
                    if validity_check_function(selected_piece, i, j) and (i ~= selected_piece.x or j ~= selected_piece.y) then
                        table.insert(valid_moves, {cell_x = i, cell_y = j})
                    end
                end
            end
        end
    end
end

function love.mousereleased(x, y, b)
    if b == 1 then
        mouse_down = false
        
        if selected_piece then

            -- check if a move is being made
            local cell_x, cell_y = get_cell(x, y)

            if is_valid_cell(cell_x, cell_y) then
                make_move(cell_x, cell_y)
            end

            selected_piece.ox = 0
            selected_piece.oy = 0
            selected_piece = nil
            valid_moves = {}
        end
    end
end

function love.draw()
    
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(background_sprite, 0, 0)

    draw_board()
    draw_clock()
    draw_captured()

end
