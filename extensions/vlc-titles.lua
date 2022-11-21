--[[

VLC add-on "VLC-Titles" is used for downloading subtitles from site Titlovi.com
inside VLC player. Start movie and from menu View -> Titles launch this add-on

The subtitle file will be saved in the same folder where the movie resides or in
user's home folder. The add.on can download subtitles in SRT format or ones 
aricheved within ZIP file.

For loading and decompression of data from ZIP archive this add-on uses the
following libraries: zzlib, inflate-bit32, numberlua 

--]]


title = "VLC-Titles"
version = "1.6"

program = title .. " " ..version

config_file = "vlc-titles.conf"
config = ""

icon = "\137\80\78\71\13\10\26\10\0\0\0\13\73\72\68\82\0\0\0\32\0\0\0\32\4\3\0\0"..
       "\0\129\84\103\199\0\0\0\27\80\76\84\69\130\48\69\29\29\29\69\69\69\94\94"..
       "\94\121\121\121\146\146\146\177\177\177\201\201\201\234\234\234\126\204"..
       "\192\130\0\0\0\1\116\82\78\83\0\64\230\216\102\0\0\0\124\73\68\65\84\40"..
       "\207\99\96\160\46\96\20\20\64\225\43\10\10\10\34\113\211\59\138\145\5\4"..
       "\5\35\58\58\2\225\2\108\229\138\130\194\29\29\197\48\179\68\59\58\90\4\5"..
       "\213\18\224\102\11\122\0\149\11\32\89\38\40\92\158\128\98\59\138\109\80"..
       "\21\229\37\130\130\225\229\229\138\2\16\1\176\149\106\64\107\4\33\2\98"..
       "\29\29\205\130\194\21\29\109\130\96\1\38\37\36\160\64\164\64\40\28\224"..
       "\18\160\135\22\6\100\45\212\137\79\0\21\236\54\197\104\55\24\83\0\0\0\0"..
       "\73\69\78\68\174\66\96\130"

dlg_cbox = {}
dlg_sel_set = false
buf = ""

pg=1
rpp=15
r=0

jezici = { [1] = {"ba","bosanski","Bosnian",1,8},
           [4] = {"hr","hrvatski","Croatian",10,8},
           [5] = {"mk","makedonski","Macedonian",18,12},
           [6] = {"si","slovenski","Slovenian",31,10},
           [7] = {"rs","srpski","Serbian",43,12},
           [2] = {"ћ", "cirilica","Cyrilic",55,12},
           [3] = {"en","english","English",69,12} }

sortiranje = { [0] = "-",
               [1] = "by name",
               [2] = "by language",
               [3] = "by uploader",
               [4] = "by upload date",
               [5] = "by status",
               [6] = "by num of download",
               [7] = "by num of comments",
               [8] = "by num of marks",
               [9] = "by mark" }

tipovi = { [0] = "-",
           [1] = "movie",
           [2] = "series",
           [3] = "documentary" }
           
           
local zzlib = require("zzlib")


function descriptor()
  return {
    title = program,
    icon = icon,
    version = version,
    author = "Stjepan Brbot",
    url = "https://github.com/sbrbot/vlc-titlovi",
    description = "Download of titles form site http://titlovi.com",
    capabilities = {"menu"}
  }
end

function activate()

  dlg = vlc.dialog(program)
  
  -- 1st line ------------------------------------------------------------------

  dlg:add_label("<small>Tile language filter:</small>",1,1,80,1)
  
  for key,val in pairs(jezici) do
    dlg_cbox[key] = dlg:add_check_box(val[3],false,val[4],2,val[5],1)
  end

  -- 2nd line ------------------------------------------------------------------

  dlg:add_label("<small>Sorting of results:</small>",1,3,60,1)
  dlg:add_label("<small>Content type:</small>",61,3,20,1)
  dlg:add_label("<small>Uploader:</small>",81,3,20,1)
  
  dlg_sort = dlg:add_dropdown(1,4,60,2)
  for key,val in pairs(sortiranje) do
    dlg_sort:add_value(val,key)
  end
  dlg_type = dlg:add_dropdown(61,4,20,2)
  for key,val in pairs(tipovi) do
    dlg_type:add_value(val,key)
  end
  dlg_upld = dlg:add_text_input("",81,4,20,2)

  -- 3rd line ------------------------------------------------------------------

  dlg:add_label(" ",1,7,80)
  dlg:add_label("<small>Part of name for search:</small>",1,8,60)
  dlg:add_label("<small>Season:</small>",61,8,7)
  dlg:add_label("<small>Episode:</small>",68,8,7)
  dlg:add_label("<small>Year:</small>",75,8,6)
  
  vlc.msg.info("[VLC-Titles] Video name: " .. getVideoNameWoExt())
  
  dlg_txt = dlg:add_text_input(cleanKeywords(getVideoNameWoExt()),1,9,60)
  local s = string.match(getVideoNameWoExt(),".*[sS](%d?%d)")
  if(s == nil) then s="" end
  dlg_sez = dlg:add_text_input(s,61,9,7)
  local e = string.match(getVideoNameWoExt(),".*[eE](%d?%d)")
  if(e == nil) then e="" end
  dlg_epi = dlg:add_text_input(e,68,9,7)
  local g = string.match(getVideoNameWoExt(),".-(%d%d%d%d)")
  if(g == nil) then g="" end
  dlg_gdn = dlg:add_text_input(g,75,9,6)
  dlg_btn = dlg:add_button("Search",find_first,81,9,20,1)
  
  -- 4th line ------------------------------------------------------------------

  dlg_res = dlg:add_label(getFilePath(),1,10,80)
  dlg:add_button("<",find_prev,81,10,6)
  dlg_pg  = dlg:add_label("<center>1</center>",89,10,4)
  dlg:add_button(">",find_next,95,10,6)
  
  -- 4.1st line ----------------------------------------------------------------
  
  dlg_lst = dlg:add_list(1,12,80,32)
  dlg:add_label("<center><small>page</small></center>",81,12,20)
  
  -- 4.2nd line ----------------------------------------------------------------
  
  dlg:add_button("Load",load,81,15,20)
  
  -- 4.3rd line ----------------------------------------------------------------

  dlg_typ = dlg:add_label("",81,16,20) --ZIP/SRT
  
  -- 4.4th line ----------------------------------------------------------------

  if(getFilePath() ~= "") then
    dlg_map = dlg:add_label("<center><a href=\"file:///" .. getFilePath() .. "\">Folder</a></center>",81,30,20)
  end
  
  -- 4.5th line ----------------------------------------------------------------

  dlg:add_button("Help",about,81,36,20)
  
  -- 4.6th line ----------------------------------------------------------------
  
  dlg:add_label("<center><small>&copy; by <a href=\"mailto:stjepan.brbot@gmail.com\">Stjepan Brbot</a>, 2021</small></center>",81,42,20)

  ------------------------------------------------------------------------------
  
  loadConfig()

  dlg:show()

end

function find_first()
  pg=1
  find(pg)
end

function find_prev()
  if(pg>1) then 
    pg = pg - 1
    find(pg)
  end
end

function find_next()
  if(pg<math.ceil(r/rpp)) then
    pg = pg + 1
    find(pg)
  end
end

function find(pg)

  dlg_pg:set_text("<center>" .. pg .. "</center>");

  r = 0
  
  if(dlg_txt:get_text() ~= "") then

    local s,e

    dlg_btn:set_text("Wait")
    dlg_typ:set_text("")
    dlg_lst:clear()
    
    dlg_icn = dlg:add_spin_icon(89,7,4,2)
    dlg_icn:animate()
    dlg:update()
    
    local url = "https://titlovi.com/titlovi/?prijevod=" .. vlc.strings.encode_uri_component(dlg_txt:get_text())

    local ojezici = {}
    for key,val in pairs(jezici) do
      if dlg_cbox[key]:get_checked() then table.insert(ojezici,val[2]) end
    end

    if(table.concat(ojezici,"|") ~= "") then 
      url = url .. "&jezik=" .. table.concat(ojezici,"|") 
    end
    if(dlg_sort:get_value() ~= 0) then 
      url = url .. "&sort=" .. dlg_sort:get_value() 
    end
    if(dlg_type:get_value() ~= 0) then 
      url = url .. "&t=" .. dlg_type:get_value() 
    end
    if(dlg_sez:get_text() ~= "") then
      s = tonumber(dlg_sez:get_text())
      if not s then s = 0 end
      dlg_sez:set_text(s)
      url = url .. "&s=" .. s 
    end
    if(dlg_epi:get_text() ~= "") then 
      e = tonumber(dlg_epi:get_text())
      if(not e or s == 0) then e = 0 end
      dlg_epi:set_text(e)
      url = url .. "&e=" .. e
    end
    if(dlg_gdn:get_text() ~= "") then 
      g = tonumber(dlg_gdn:get_text())
      if not g then g = "" end
      dlg_gdn:set_text(g)
      url = url .. "&g=" .. g
    end
    if(dlg_upld:get_text() ~= "") then 
      url = url .. "&korisnik=" .. vlc.strings.encode_uri_component(dlg_upld:get_text()) 
    end
    
    url = url .. "&pg=" .. pg
    
    vlc.msg.info("[VLC-Titles] url = " .. url)
    
    local data = vlc.stream(url):read(4^8);

    r = tonumber(getTagContent(string.sub(data,string.find(data,"Našli smo.-rezultata")),"b"))
    
    if(r > 0) then
    
      local ul,li,id,h3,h4,ss,ee,naslov,lang

      ul = string.sub(data,string.find(data,"<ul class=\"titlovi.+<div class=\"paging\">"))

      s,e = string.find(ul,"<h3.-h5>")
      while (e ~= nil) do
      
        li = string.sub(ul,s,e)
        
        id = getTagAttribute(li,"data%-id")
        
        h3 = getTagContent(li,"h3")

        naslov = getTagContent(li,"a")
        if(getTagContent(h3,"i") ~= "") then naslov = naslov .. " " .. getTagContent(h3,"i") end
        if(getTagContent(h3,"span") ~= "") then naslov = naslov .. " " .. getTagContent(h3,"span") end
        
        h4 = getTagContent(li,"h4")
        ss,ee = string.find(h4,"<span")
        naslov = naslov .. " " .. string.sub(h4,1,ss-1)

        lang = tonumber(string.match(li,"alt=\"(%d)\""))        

        dlg_lst:add_value("[" .. jezici[lang][1] .. "] " .. naslov,id)

        s,e = string.find(ul,"<h3.-h5>",e)
        
      end
      
    end
    
    if(dlg_sel_set) then 
      dlg:del_widget(dlg_sel)
      dlg_sel_set = false
    end

    dlg_btn:set_text("Search")
    
    dlg_icn:stop()
    dlg:del_widget(dlg_icn)
    dlg:update()
    
    dlg_res:set_text("Found: <b>" .. r .. "</b>")
        
    vlc.msg.dbg("[VLC-Titles] Site search finished")
  
  end
  
end

function load()

  buf = ""
  
  dlg_icn = dlg:add_spin_icon(89,7,4,2)
  dlg_icn:animate()
  dlg:update()

  local url = "https://titlovi.com/download/?type=2&mediaid="

  for key,val in pairs(dlg_lst:get_selection()) do
  
    url = url .. key

    local stream = vlc.stream(url)
    if not stream then
      vlc.msg.warn("[VLC-Titles] Website Titlovi.com unavailable ") 
      return false 
    end
    local data = stream:read(8^4)
    while(data ~= nil and data ~= "") do
      buf = buf .. data
      data = stream:read(8^4)
    end
    
    vlc.msg.dbg("[VLC-Titles] Site data loaded")

    if(string.sub(buf,1,2) == "PK") then -- Phil Katz
      dlg_typ:set_text("<center>ZIP<c/enter>")
      local filenames = zzlib.zipfilenames(buf)
      if(zzlib.zipfilesnum(buf) == 1) then
        save(zzlib.unzip(buf,filenames[1]),filenames[1])
      else
        dlg_lst:clear()
        for key,val in pairs(filenames) do
          dlg_lst:add_value(val,key)
        end
        dlg_sel = dlg:add_button("Select",select,81,15,20)
        dlg_sel_set = true
      end
    else
      dlg_typ:set_text("<center>SRT</center>")
      save(buf,"VLC-titles.srt")
    end
    
    break

  end

  dlg_icn:stop()
  dlg:del_widget(dlg_icn)
  dlg:update()
    
end

function select()

  dlg_icn = dlg:add_spin_icon(89,7,4,2)
  dlg_icn:animate()
  dlg:update()

  for idx,filename in pairs(dlg_lst:get_selection()) do
    save(zzlib.unzip(buf,filename),filename)
    break -- save only the first record
  end
  
  vlc.msg.dbg("[VLC-Titles] ZIP archive data loaded")

  dlg_icn:stop()
  dlg:del_widget(dlg_icn)
  dlg:update()
    
end

function save(data,filename)

  if(vlc.input.item()) then
    filename = getVideoNameWoExt() .. ".srt"
  else
    filename = getFilePath() .. filename
  end
  local f = assert(io.open(filename,"wt"))
  f:write(data)
  f:close()
  
  if(vlc.input.item()) then
    vlc.input.add_subtitle(filename,true)
  end
  dlg_typ:set_text("<center>Saved!</center>")

  vlc.msg.info("[VLC-Titles] Title saved: " .. filename)

end

--

function about()
  html = dlg:add_html("<h3>About</h3>this add-on for VLC player is used for automatic download of" 
  .." titles from regional website <a href=\"http://titlovi.com\">Titlovi.com</a>. " 
  .."<ul><li>select title language, sorting type, content type, and optionally title uploader</li>"
  .."<li>insert 2-3 keywords from title name (do not insert too much because it could highly reduce results)</li>"
  .."<li>insert the season with number (0 means all seasons) and/or some episode from season/series"
  .."<li>run the search with button [<u>Search</u>] and found titles will be shown in list</li>"
  .."<li>select the title from this list (could be in SRT or ZIP format) and load it with button [<u>Load</u>]</li>"
  .."<li>if the file is a ZIP archieve with more titles, particlar title one can select with button [<u>Select</u>]</li></ul>"
  .." The title file will be stored in folder where the movie file resides with the same filename as movie and extension .srt"
  .." If the movie is not being palayed at the moment of search, then the found title will be saved in users home folder."
  .." This VLC add-on one can find on website: <a href=\"https://addons.videolan.org/p/1572365\">VLC-Titles</a>",1,12,80,32)
  oprg = dlg:add_button("ok",help,81,36,20)
  dlg:update()
end

function help()
  dlg:del_widget(html)
  dlg:del_widget(oprg)
  dlg:update()
end

--

function loadConfig()
  config = vlc.config.configdir() .. "/" .. config_file
  if not vlc.io.open(config,'r') then 
    saveConfig()
  else
    local line,val
    local file=io.open(config,"rt")
    for i=1,#jezici do
      val = string.match(file:read(),"=%s*([01])")
      dlg_cbox[i]:set_checked(val=="1" and true or false)
    end
    file:close()
  end
  vlc.msg.info("[VLC-Titles] Configuration loaded")
end

function saveConfig()
  local langs = ""
  local file=io.open(config,"wt")
  for i=1,#jezici do
    langs = langs .. jezici[i][1] .. "=" .. (dlg_cbox[i]:get_checked() and 1 or 0) .. "\n"
  end
  file:write(langs)
  file:close()
  vlc.msg.info("[VLC-Titles] Configuration saved")
end

function getVideoNameWoExt()
  if(getVideoName() ~= "") then
    return getVideoName():match("(.+)%.")
  end
  return ""
end

function getVideoName()
  if(vlc.input.item()) then
    local metas = vlc.input.item():metas()
    if metas ~= nil then return metas["filename"] end
  end
  return ""
end

function getFilePath()
  local uri
  if(vlc.input.item()) then
    uri = vlc.input.item():uri()
    uri = string.gsub(uri,"^file:///","")
    uri = uri:match("(.*[/\\])")
  else
    uri = vlc.config.homedir() .. "\\"
  end
  if(string.match(vlc.config.homedir(),"^(%a:.+)$")) then
    uri = string.gsub(uri,"/","\\") --windows
  else
    uri = string.gsub(uri,"\\","/") --linux
  end
  return vlc.strings.decode_uri(uri)
end

function getTagContent(html,tag)
  local s1,e1 = string.find(html,"<" .. tag .. ".-" .. ">")
  if(e1 == nil) then return "" end
  local s2,e2 = string.find(html,"</" .. tag .. ">",e1)
  if(s2 == nil) then return "" end
  return string.sub(html,e1+1,s2-1)
  --return string.match(html,"<"..tag..".->(.-)<%s*%/%s*"..tag.."%s*>")
end

function getTagAttribute(html,attr)
  local s1,e1 = string.find(html,attr .. "=\"")
  local s2,e2 = string.find(html,"\"",e1+1)
  return (e1 ~= nil and s2 ~= nil) and string.sub(html,e1+1,s2-1) or ""
  --return string.match(html,attr.."%s*=%s*\"(%d+)\"")
end

function cleanKeywords(text)
  if(text ~= "") then
    --oznake koje se uklanjaju iz naziva datoteke filma za bolje pretraživanje titla
    local pattern = { "360p","480p","720p","1080p","2160p","4320p","HEVC","XviD","XVID",
                      "MP4","MKV","WEB DL","WEBRip","Mp4","mp4","mkv","MPEG","MP3","XXX",
                      "BRrip","BrRip","DVDrip","WEBrip","WebRip","BluRay","H264","H265","x264","DvdRip","HDrip","HDRip",
                      "x265","AAC","AC3","HDTV","HDMI","HDR 5.1","DTS","FiHTV",
                      "aXXo","YIFY","-EVO","CtrlHD","RoCK","TURMOiL","-MEMENTO","TGx",
                      "ShAaNiG","eztv","-FQM","-CTU","-ASAP","REFiNED","COALiTiON",
                      "-GalaxyRG","YTS","-PHOENiX","TiTAN","-CPG","-NOGRP","EtHD",
                      "-EXPLOIT","-END","MkvCage","-CODEX","eztv","-EMPATHY","-CMRG",
                      "QxR","-GoT","-MiNX","-RARBG","-ION10","-CYBER","-PSA","-MT",
                      "-CAKES","-TORRENTGALAXY","-NWCHD","-AFG","-SYNCOPY","Deep61",
                      "-CAFFEiNET","ESub"," - ItsMyRip","-BAE","-TIMECUT","TJET","-worldmkv",
                      "-CM","-VXT"," - LOKiDH"," - EMBER"," BONE","TheUpscaler","-NAHOM"}
    for _,val in pairs(pattern) do
      if(text ~= "") then text = string.gsub(text,val,"") end
    end
    text = string.gsub(text,"%."," ")
    text = string.gsub(text,"%[","")
    text = string.gsub(text,"%]"," ")
    text = string.gsub(text,"[sS]%d?%d","")
    text = string.gsub(text,"[eE]%d?%d","")
    text = string.gsub(text,"[12][90]%d%d","")
  end
  return text
end

--

function menu()
  return {title}
end

function trigger_menu(id)
  dlg:update()
end

function close()
  vlc.deactivate()
end

function deactivate()
  saveConfig()
  dlg:delete()
end