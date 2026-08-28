local Colors = {}
Colors._VERSION = '0.1.5'
Colors.__index = Colors

local function round(value)
    return math.floor(value + 0.5)
end

local clr = {
    GRAD1 = 0xB4B5B7, -- #B4B5B7
    GRAD2 = 0xBFC0C2, -- #BFC0C2
    GRAD3 = 0xCBCCCE, -- #CBCCCE
    GRAD4 = 0xD8D8D8, -- #D8D8D8
    GRAD5 = 0xE3E3E3, -- #E3E3E3
    GRAD6 = 0xF0F0F0, -- #F0F0F0
    GREY = 0xAFAFAF, -- #AFAFAF
    RED = 0xAA3333, -- #AA3333
    ORANGE = 0xFF8000, -- #FF8000
    YELLOW = 0xFFFF00, -- #FFFF00
    FORSTATS = 0xFFFF91, -- #FFFF91
    HOUSEGREEN = 0x00E605, -- #00E605
    GREEN = 0x33AA33, -- #33AA33
    LIGHTGREEN = 0x9ACD32, -- #9ACD32
    CYAN = 0x40FFFF, -- #40FFFF
    PURPLE = 0xC2A2DA, -- #C2A2DA
    BLACK = 0x000000, -- #000000
    WHITE = 0xFFFFFF, -- #FFFFFF
    FADE1 = 0xE6E6E6, -- #E6E6E6
    FADE2 = 0xC8C8C8, -- #C8C8C8
    FADE3 = 0xAAAAAA, -- #AAAAAA
    FADE4 = 0x8C8C8C, -- #8C8C8C
    FADE5 = 0x6E6E6E, -- #6E6E6E
    LIGHTRED = 0xFF6347, -- #FF6347
    NEWS = 0xFFA500, -- #FFA500
    TEAM_NEWS_COLOR = 0x049C71, -- #049C71
    TWPINK = 0xE75480, -- #E75480
    TWRED = 0xFF0000, -- #FF0000
    TWBROWN = 0x654321, -- #654321
    TWGRAY = 0x808080, -- #808080
    TWOLIVE = 0x808000, -- #808000
    TWPURPLE = 0x800080, -- #800080
    TWTAN = 0xD2B48C, -- #D2B48C
    TWAQUA = 0x00FFFF, -- #00FFFF
    TWORANGE = 0xFF8C00, -- #FF8C00
    TWAZURE = 0x007FFF, -- #007FFF
    TWGREEN = 0x008000, -- #008000
    TWBLUE = 0x0000FF, -- #0000FF
    LIGHTBLUE = 0x33CCFF, -- #33CCFF
    FIND_COLOR = 0xB90000, -- #B90000
    TEAM_AZTECAS_COLOR = 0x01FCFF, -- #01FCFF
    TEAM_TAXI_COLOR = 0xF2FF00, -- #F2FF00
    DEPTRADIO = 0xFFD700, -- #FFD700
    TEAM_BLUE_COLOR = 0x2641FE, -- #2641FE
    TEAM_FBI_COLOR = 0x8D8DFF, -- #8D8DFF
    TEAM_MED_COLOR = 0xFF8282, -- #FF8282
    TEAM_APRISON_COLOR = 0x9C7912, -- #9C7912
    NEWBIE = 0x7DAEFF, -- #7DAEFF
    PINK = 0xFF66FF, -- #FF66FF
    OOC = 0xE0FFFF, -- #E0FFFF
    PUBLICRADIO_COLOR = 0x6DFB6D, -- #6DFB6D
    TEAM_GROVE_COLOR = 0x00D900, -- #00D900
    REALRED = 0xFF0606, -- #FF0606
    REALGREEN = 0x00FF00, -- #00FF00
    MONEY = 0x2F5A26, -- #2F5A26
    MONEY_NEGATIVE = 0x9C1619, -- #9C1619
    BETA = 0x5D8AA8, -- #5D8AA8
    DEV = 0xC27C0E, -- #C27C0E
    ARES = 0x1C77B3, -- #1C77B3
    DARKGREY = 0x1A1A1A, -- #1A1A1A
    ALTRED = 0x661F1F, -- #661F1F
    BLUE = 0xB7D1EB, -- #B7D1EB
    DD = 0x8ABFF5, -- #8ABFF5
    OOC = 0x6F570E, -- #6F570E
    GOV = 0xBEBEBE, -- #BEBEBE
    SASD = 0xCC9933, -- #CC9933
    LIGHTGREY = 0xB4B4B4, -- #B4B4B4
    LIGHTGREY2 = 0xBBBBBB, -- #BBBBBB
    LSPD = 0x2B60DE -- #2B60DE
}

for name, color in pairs(clr) do
    _G["clr_"..name] = color
end

function Colors.list()
    return clr
end

function Colors.convertColor(color, normalize, includeAlpha, outputHSVA)
    if type(color) ~= "number" then
        error("Invalid color value. Expected a number.")
    end

    local a = includeAlpha and bit.band(bit.rshift(color, 24), 0xFF) or 255
    local r = bit.band(bit.rshift(color, 16), 0xFF)
    local g = bit.band(bit.rshift(color, 8), 0xFF)
    local b = bit.band(color, 0xFF)

    if normalize then
        a, r, g, b = a / 255, r / 255, g / 255, b / 255
    end

    if outputHSVA then
        local h, s, v = Colors.RGBtoHSV(r, g, b) -- was a bare RGBtoHSV: nil global, crashed any outputHSVA caller
        if includeAlpha then
            return {h = h, s = s, v = v, a = a}
        else
            return {h = h, s = s, v = v}
        end
    end

    if includeAlpha then
        return {r = r, g = g, b = b, a = a}
    else
        return {r = r, g = g, b = b}
    end
end

function Colors.joinARGB(a, r, g, b, normalized)
    if normalized then
        a, r, g, b = round(a * 255), round(r * 255), round(g * 255), round(b * 255)
    end

    local function clamp(value)
        return math.max(0, math.min(255, value))
    end

    a, r, g, b = clamp(a), clamp(r), clamp(g), clamp(b)

    local color = bit.bor(
        bit.lshift(a, 24), 
        bit.lshift(r, 16), 
        bit.lshift(g, 8), 
        b
    )

    return color
end

-- ARGB (or any alpha-in-top-byte format) -> pure 0xRRGGBB. The canonical way
-- to turn sampGetPlayerColor's 0xAARRGGBB into a key for RRGGBB-keyed tables
-- (factions.badges, extraBadges, factions.colors) or a {%06x} inline tag.
function Colors.stripAlpha(color)
    return bit.band(color, 0xFFFFFF)
end

function Colors.changeAlpha(color, newAlpha, format)
    newAlpha = math.max(0, math.min(255, newAlpha))
    format = format or "ARGB"

    if format == "ARGB" then
        local rgb = bit.band(color, 0x00FFFFFF)
        return bit.bor(bit.lshift(newAlpha, 24), rgb)
    elseif format == "RGBA" then
        local rgb = bit.band(color, 0xFFFFFF00)
        return bit.bor(rgb, newAlpha)
    else
        error("Invalid format specified. Use 'ARGB' or 'RGBA'.")
    end
end

function Colors.toUnsignedColor(color)
    return color % (2^32)
end

-- Convert normalized RGB to HSV
function Colors.RGBtoHSV(r, g, b)
    local max = math.max(r, g, b)
    local min = math.min(r, g, b)
    local delta = max - min

    local h, s, v = 0, 0, max

    if delta > 0 then
        if max == r then
            h = (g - b) / delta % 6
        elseif max == g then
            h = (b - r) / delta + 2
        else -- max == b
            h = (r - g) / delta + 4
        end
        h = h * 60
        if h < 0 then h = h + 360 end

        s = delta / max
    else
        h = 0
        s = 0
    end

    -- Handle edge cases for white and black
    if max == 0 then
        s = 0
    end

    return h, s, v
end

-- Convert HSV to normalized RGB
function Colors.HSVtoRGB(h, s, v)
    local c = v * s
    local x = c * (1 - math.abs((h / 60) % 2 - 1))
    local m = v - c

    local r1, g1, b1 = 0, 0, 0

    if h >= 0 and h < 60 then
        r1, g1, b1 = c, x, 0
    elseif h >= 60 and h < 120 then
        r1, g1, b1 = x, c, 0
    elseif h >= 120 and h < 180 then
        r1, g1, b1 = 0, c, x
    elseif h >= 180 and h < 240 then
        r1, g1, b1 = 0, x, c
    elseif h >= 240 and h < 300 then
        r1, g1, b1 = x, 0, c
    else -- h >= 300 and h < 360
        r1, g1, b1 = c, 0, x
    end

    local r = r1 + m
    local g = g1 + m
    local b = b1 + m

    return r, g, b
end

return Colors