--[[

VLC addon (dodatak) "VLC-Titlovi" služi za skidanje titlova sa sajta Titlovi.com
unutar VLC pregledika. Pokrenite film i iz izbornika View -> Titovi poreknite
ovaj dodatak kojim tražite titlove. 

Titl će biti snimljen u isti folder u kojem se nalazi i film ili u korisnikov
folder. Program može skidati titlove direktno u SRT formatu ili zapakirane 
unutar ZIP arhive.

Za čitanje i dekompresiju podataka unutar ZIP arhive ovaj program korisiti
biblioteke: zzlib, inflate-bit32 i numberlua 

--]]


title = "VLC-Titlovi"
version = "1.0"
program = title .. " " ..version

icon = "\137\80\78\71\13\10\26\10\0\0\0\13\73\72\68\82\0\0\0\32\0\0\0\32\4\3\0\0\0\129\84\103\199\0\0\0\27\80\76\84\69\130\48\69\29\29\29\69\69\69\94\94\94\121\121\121\146\146\146\177\177\177\201\201\201\234\234\234\126\204\192\130\0\0\0\1\116\82\78\83\0\64\230\216\102\0\0\0\124\73\68\65\84\40\207\99\96\160\46\96\20\20\64\225\43\10\10\10\34\113\211\59\138\145\5\4\5\35\58\58\2\225\2\108\229\138\130\194\29\29\197\48\179\68\59\58\90\4\5\213\18\224\102\11\122\0\149\11\32\89\38\40\92\158\128\98\59\138\109\80\21\229\37\130\130\225\229\229\138\2\16\1\176\149\106\64\107\4\33\2\98\29\29\205\130\194\21\29\109\130\96\1\38\37\36\160\64\164\64\40\28\224\18\160\135\22\6\100\45\212\137\79\0\21\236\54\197\104\55\24\83\0\0\0\0\73\69\78\68\174\66\96\130"

dlg_cbox = {}
dlg_sel_set = false
buf = ""

pg=1
rpp=15
r=0

jezici = { [1] = {"ba","bosanski","bošnjački",1},
           [4] = {"hr","hrvatski","hrvatski",13},
           [5] = {"mk","makedonski","makedonski",24},
           [6] = {"si","slovenski","slovenski",37},
           [7] = {"rs","srpski","srpski",49},
           [2] = {"ћ", "cirilica","ћирилица",57},
           [3] = {"en","english","engleski",70} }

sortiranje = { [0] = "-",
               [1] = "po imenu",
               [2] = "po jeziku",
               [3] = "po uploaderu",
               [4] = "po datumu uploada",
               [5] = "po statusu",
               [6] = "po broju downloada",
               [7] = "po broju komentara",
               [8] = "po broju ocjena",
               [9] = "po ocjeni" }

tipovi = { [0] = "-",
           [1] = "film",
           [2] = "serija",
           [3] = "dokumentarac" }


local zzlib = require("zzlib")


function descriptor()
  return {
    title = program,
    icon = icon,
    version = version,
    author = "Stjepan Brbot",
    url = "https://github.com/sbrbot/vlc-titlovi",
    description = "Skidanje titlova sa sajta http://titlovi.com",
    capabilities = {"menu"}
  }
end

function activate()

  dlg = vlc.dialog(program)

  dlg:add_label("<small>Filter za jezik titlova:</small>",1,1,80,1)
  
  for key,val in pairs(jezici) do
    dlg_cbox[key] = dlg:add_check_box(val[3],false,val[4],2,20,1)
    --if(vlc.config.get(val[1])=="1") then dlg_cbox[key]:set_checked(true) end
  end

  dlg:add_label("<small>Sortiranje rezultata:</small>",1,3,40,1)
  dlg:add_label("<small>Tip sadržaja:</small>",41,3,40,1)
  dlg:add_label("<small>Uploader:</small>",81,3,20,1)
  
  dlg_sort = dlg:add_dropdown(1,4,40,2)
  for key,val in pairs(sortiranje) do
    dlg_sort:add_value(val,key)
  end
  dlg_type = dlg:add_dropdown(41,4,40,2)
  for key,val in pairs(tipovi) do
    dlg_type:add_value(val,key)
  end
  dlg_uld = dlg:add_text_input("",81,4,20,2)

  dlg:add_label("<small>Dio imena za pretraživanje:</small>",1,7,80,1)

  dlg_txt = dlg:add_text_input(getKeywords(getVideoNameWoExt()),1,8,80,2)
  dlg_btn = dlg:add_button("Pronađi",find_first,81,8,20,2)

  dlg_res = dlg:add_label(getFilePath(),1,10,80)
  dlg:add_button("<",find_prev,81,10,8)
  dlg_pg  = dlg:add_label("<center>1</center>",90,10,2)
  dlg:add_button(">",find_next,93,10,8)
  
  --
  
  dlg_lst = dlg:add_list(1,12,80,12)
  dlg:add_label("<center><small>stranica</small></center>",81,12,20)
  
  dlg:add_button("Učitaj",load,81,13,20)

  dlg_typ = dlg:add_label("",81,14,20) --ZIP/SRT

  if(getFilePath() ~= "") then
    dlg_map = dlg:add_label("<center><a href=\"file:///" .. getFilePath() .. "\">Folder</a></center>",81,18,20)
  end

  dlg:add_button("Pomoć",about,81,20,20)
  
  dlg:add_label("<center><small>&copy; by <a href=\"mailto:stjepan.brbot@gmail.com\">Stjepan Brbot</a>, 2021</small></center>",81,22,20)

  dlg:show()

end

function find_first()
  pg=1
  dlg_pg:set_text("<center>" .. pg .. "</center>");
  find(pg)
end

function find_prev()
  if(pg>1) then 
    pg = pg - 1
    dlg_pg:set_text("<center>" .. pg .. "</center>");
    find(pg)
  end
end

function find_next()
  if(pg<math.ceil(r/rpp)) then
    pg = pg + 1
    dlg_pg:set_text("<center>" .. pg .. "</center>");
    find(pg)
  end
end

function find(pg)

  r = 0

  if(dlg_txt:get_text() ~= "") then

    dlg_btn:set_text("Čekaj")
    dlg_typ:set_text("")
    dlg_lst:clear()
    
    --dlg_icn = dlg:add_spin_icon(90,16)
    --dlg_icn:animate()
    --dlg:update()

    local url = "https://titlovi.com/titlovi/?prijevod=" .. string.gsub(dlg_txt:get_text()," ","%+") .. "&pg=" .. pg

    local ojezici = {}
    for key,val in pairs(jezici) do
      if dlg_cbox[key]:get_checked() then table.insert(ojezici,val[2]) end
    end

    if(table.concat(ojezici,"|") ~= "") then url = url .. "&jezik=" .. table.concat(ojezici,"|") end
    if(dlg_sort:get_value() ~= 0) then url = url .. "&sort=" .. dlg_sort:get_value() end
    if(dlg_type:get_value() ~= 0) then url = url .. "&t=" .. dlg_type:get_value() end
    if(dlg_uld:get_text() ~= "") then url = url .. "&korisnik=" .. string.gsub(dlg_uld:get_text()," ","%+") end
    
    local data = vlc.stream(url):read(4^8);

    r = tonumber(getTagContent(string.sub(data,string.find(data,"Našli smo.-rezultata")),"b"))
    
    if(r > 0) then
    
      local ul,li,id,h3,h4,ss,ee,naslov,lang

      ul = string.sub(data,string.find(data,"<ul class=\"titlovi.+<div class=\"paging\">"))

      local s,e = string.find(ul,"<h3.-h5>")
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

        ss,ee = string.find(li,"alt=\"%d\"")
        lang = tonumber(string.sub(li,ss+5,ee-1))
        
        dlg_lst:add_value("[" .. jezici[lang][1] .. "] " .. naslov,id)

        s,e = string.find(ul,"<h3.-h5>",e)
        
      end
      
    end
    
    if(dlg_sel_set) then 
      dlg:del_widget(dlg_sel)
      dlg_sel_set = false
    end

    dlg_btn:set_text("Pronađi")
    
    --dlg_icn:stop()
    --dlg:del_widget(dlg_icn)
    --dlg:update()
    
    dlg_res:set_text("Pronađeno: <b>" .. r .. "</b>")
        
    vlc.msg.dbg("[VLC-titlovi] Završena pretraga sajta")
  
  end
  
end

function load()

  buf = ""
  
  local url = "https://titlovi.com/download/?type=2&mediaid="

  for key,val in pairs(dlg_lst:get_selection()) do
  
    url = url .. key

    local stream = vlc.stream(url)
    local data = stream:read(8^4)
    while(data ~= nil and data ~= "") do
      buf = buf .. data
      data = stream:read(8^4)
    end
    
    vlc.msg.dbg("[VLC-titlovi] Podaci učitani sa sajta")

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
        dlg_sel = dlg:add_button("Odaberi",select,81,13,20)
        dlg_sel_set = true
      end
    else
      dlg_typ:set_text("<center>SRT</center>")
      save(buf,"VLC-titlovi.srt")
    end
    
    break

  end
end

function select()

  for idx,filename in pairs(dlg_lst:get_selection()) do
    save(zzlib.unzip(buf,filename))
    break -- spremi samo prvi zapis
  end
  
  vlc.msg.dbg("[VLC-titlovi] Pročitani podaci iz ZIP arhive")

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
  dlg_typ:set_text("<center>Snimljeno!</center>")

  vlc.msg.dbg("[VLC-titlovi] Titl snimljen: " .. filename)

end

function getVideoNameWoExt()
  if(getVideoName() ~= "") then
    return getVideoName():match("(.+)%..+$")
  end
  return ""
end

--

function about()
  html = dlg:add_html("<h4>O programu</h4>Ovaj dodatak za VLC player služi za automatsko skidanje" 
  .." titlova sa regionalnog sajta <a href=\"http://titlovi.com\">Titlovi.com</a>. " 
  .."<ul><li>odaberite jezike titla, vrstu sortiranja rezultata, vrstu sadržaja i ev. upladera titla</li>"
  .."<li>unesite 2-3 ključne riječi iz imena (ne pretjerujte jer od previše se smanuje pretraga)</li>"
  .."<li>pokrenite pretraživanje tipkom [<u>Pronađi</u>] nakon čega se pronađeni titlovi prikazuju u listi</li>"
  .."<li>odaberite titl s popisa (može biti da je SRT ili ZIP) i učitajte ga tipkom [<u>Učitaj</u>]</li>"
  .."<li>ako je datoteka ZIP s više titlova određeni titl možete odabrati tipkom [<u>Odaberi</u>]</li></ul>"
  .." Datoteku titla sprema se u folder u kojemu je film i istog imena kao film samo s nastavkom .srt"
  .." Ako se film ne reproducira u VLC, onda se titl snima u korisnikov osobni folder.",1,12,80,12)
  oprg = dlg:add_button("ok",help,81,20,20)
  dlg:update()
end

function help()
  dlg:del_widget(html)
  dlg:del_widget(oprg)
  dlg:update()
end

--

function getVideoName()   
  return (vlc.input.item()) and vlc.input.item():name() or  ""
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
  local s2,e2 = string.find(html,"</" .. tag .. ">",e1)
  return (e1 ~= nil and s2 ~= nil) and string.sub(html,e1+1,s2-1) or ""
end

function getTagAttribute(html,attr)
  local s1,e1 = string.find(html,attr .. "=\"")
  local s2,e2 = string.find(html,"\"",e1+1)
  return (e1 ~= nil and s2 ~= nil) and string.sub(html,e1+1,s2-1) or ""
end

function getKeywords(text)
  if(text ~= "") then
    --oznake koje se uklanjaju iz naziva datoteke filma za bolje pretraživanje titla
    local pattern = { "360p","480p","720p","1080p","2160p","4320p","HEVC","XviD","XVID",
                      "MP4","MKV","WEB DL","Mp4","mp4","mkv","MPEG","MP3","XXX",
                      "BRrip","BrRip","DVDrip","WEBrip","BluRay","H264","H265","x264",
                      "x265","AAC","AC3","HDTV","HDMI","HDR 5.1","DTS","FiHTV",
                      "aXXo","YIFY","-EVO","CtrlHD","RoCK","TURMOiL","-MEMENTO","TGx",
                      "ShAaNiG","eztv","-FQM","-CTU","-ASAP","REFiNED","COALiTiON",
                      "GalaxyRG","YTS","-PHOENiX","TiTAN","-CPG","-NOGRP","EtHD",
                      "-EXPLOIT","-END","MkvCage","-CODEX","eztv","-EMPATHY","-CMRG",
                      "QxR","-GoT","-MiNX"}
    text = string.gsub(text,"%."," ")
    text = string.gsub(text,"%[","")
    text = string.gsub(text,"%]"," ")
    for key,val in pairs(pattern) do
      text = string.gsub(text," " .. val,"")
    end
  end
  return text
end

--

function menu()
  return {title}
end

function trigger_menu(id)

end

function close()
  vlc.deactivate()
end

function deactivate()
  --[[
  for key,val in pairs(jezici) do
    if(dlg_cbox[key]:get_checked()) then 
      vlc.config.set(val[1],"1")
    else
      vlc.config.set(val[1],"0")
    end
  end
  --]]
  dlg:delete()
end