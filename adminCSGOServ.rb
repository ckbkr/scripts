# Written by Cookie Baker, first draft
require 'ripl'
require 'sqlite3'
require 'json'
require 'mysql' 
require 'optparse'
require 'pry'

class MapEntries

  def initialize
    @unpackCommand = "bzip2 -dkf " 
    @packCommand = "bzip2 -zkf9 "
    
    @serverPath = "/home/csgo/csgo_ds/csgo"
    @mapPath = "maps"
    @materialsPath = "materials"
    @modelsPath = "models"
    @ckSurfDB = "addons/sourcemod/data/sqlite/cksurf-sqlite.sq3"
    @umcConfig = [ 0, 5, 2, 2, 1, 1, 1 ]

    @storeDBHost = "localhost"
    @storeDBUser = "root"
    @storeDBPass = "lukas"
    @storeDBName = "store"
    
    @hddArms = Hash.new
    @hddSkins = Hash.new 
    @databaseSkins = Hash.new
  end

  def unpack(onlyMissing=false)
    @mapDir = @serverPath+"/"+@mapPath
    files = Dir.new(@mapDir)
    entries = files.entries
    counter = 0
    entries.each do |entry|
      counter = counter +1 
      if entry.end_with? ".bz2"
        if onlyMissing == true
          if File.exist? (@mapDir+"/"+entry[0,(entry.rindex ".bz2")])
            p "Exists: " + entry[0,(entry.rindex ".bz2")]
            next
          end
        end
        p "Progress: " + counter.to_s + "/" + entries.size.to_s
        join = "cd " + @mapDir + " && " + @unpackCommand + entry
        ret = `#{join}`
        p join
      end
    end  
    p "Done unpacking"
  end    

  def pack(onlyMissing=false)
    @mapDir = @serverPath+"/"+@mapPath
    files = Dir.new(@mapDir)
    entries = files.entries
    counter = 0
    entries .each do |entry|
     counter = counter +1 
     if entry.end_with? ".bsp"
        if onlyMissing == true
          if File.exist? (@mapDir+"/"+entry +".bz2")
            p "Exists: " + entry+".bz2"
            next
          end
        end
        p "Progress: " + counter.to_s + "/" + entries.size.to_s
        join = "cd " + @mapDir + " && " + @packCommand + entry
        ret = `#{join}`
        p join
      end
    end
    p "Done packing"
  end

  def createMapList(writeToFile=true)
    @mapDir = @serverPath+"/"+@mapPath
    mapList = File.open("maplist.txt", 'w')
    arrMapList = Array.new
    files = Dir.new(@mapDir)
    files.entries.each do |entry|
      if entry.end_with? ".bsp"
        map = entry[0,(entry.rindex ".bsp")]
        #p map
        if writeToFile == true
          mapList << map + "\n"
        end
        arrMapList.push map
      end
    end
    arrMapList
  end

  def createUMCList(mapList)
    db = SQLite3::Database.open @serverPath + "/" + @ckSurfDB 
    db.results_as_hash = true
    stm = db.prepare "SELECT mapname, count(CASE WHEN zonetype = 3 THEN 1 ELSE NULL END)+1 AS stages, \
                      (SELECT tier FROM ck_maptier b WHERE b.mapname = a.mapname) AS tier, count(DISTINCT zonegroup)-1 AS bonuses \
              FROM ck_zones a \
              GROUP BY mapname \
                      ORDER BY tier ASC; "

    rs = stm.execute
    count = 0;
    mapInfo = Hash.new
    # name, stages, tier, bonus
    while (row = rs.next) do
        #puts row.join "\s"
        count = count + 1
    #p row
        mapInfo[row['mapname']] = [  row['stages'], row['tier'],  row['bonuses'] ]
    end

    p "Maps in db: " + count.to_s
    p "Maps in list: " + mapList.length.to_s    

    mappedResult = { 0 => Array.new, 1 => Array.new, 2 => Array.new, 3 => Array.new, 4 => Array.new, 5 => Array.new, 6 => Array.new }

    count = 0

    mapcycleFile = File.open("mapcycle.txt","w")
    mapList.each do |map| 
      mapped = mapInfo[map]
      if mapped != nil
        count = count + 1
        #p "Found in db: " + map 
    #p mapped
    mapTier = 0
    if mapped[1] == nil 
          mapTier = 0
        else
          mapTier = mapped[1]
        end
        mappedResult[mapTier].push([map, mapped[0], mapped[2]])
        mapcycleFile << map + "\n"
      end
    end
    p "Mapped: " + count.to_s
    #binding.pry

    umcFile = File.open("umc_mapcycle.txt","w")
    umcFile << "\"umc_mapcycle\"\n"
    umcFile << "{\n"
    
    for i in 0..6
      if !(mappedResult[i].empty?) 
        if i == 0 
          umcFile << "    \"No Tier\"\n"
        else
          umcFile << "    \"Tier "+i.to_s+"\"\n"
        end
        umcFile << "    {\n"
        umcFile << "        \"maps_invote\" \"" + @umcConfig[i].to_s + "\"\n"
        mappedResult[i].each do |res|
          umcFile << "        \""+res[0]+"\"        { \"display\"        \""+res[0]+" (T" + i.to_s
          if res[1] > 1 
            umcFile << " " + res[1].to_s + "S"
          else
            umcFile << " L"
          end
          if res[2] > 0
            umcFile << " " + res[2].to_s + "B"
          end 
            umcFile << ")\" }\n"
        end
        umcFile << "    }\n"
      end
    end
    umcFile << "}\n"
  end

  def listMDL(parent,child,removePrefix="")
    #child = String.new(child)
    #path = String.new
    if child.empty? == true 
      path = parent
    else
      path = parent+"/"+child
    end
    curr = Dir.new(path)
    #p "Child: " + child
    #p "Current dir: " + path
    curr.entries().each do |entry|
      #p entry
      #if File.new.directory?
      if entry.end_with? ".mdl" 
        name = entry[0,entry.rindex(".mdl")]
        if name.end_with? "arms"
          while (@hddSkins[name] != nil) do
            name = name + "_"
          end
          path.slice! removePrefix
      #p path
          @hddArms[name] = { "path" => path, "file" => entry }
          next 
        end
        while (@hddSkins[name] != nil) do
          name = name + "_"
        end
        path.slice! removePrefix
        #p path
        @hddSkins[name] = { "filepath" => path, "file" => entry }
      end
      
      begin 
        if File.directory?(path+"/"+entry) && entry != ".." && entry != "." 
          listMDL path,entry,removePrefix
        end
      rescue
      end
    end
  end


  def joinArms
    @hddArms.each do |k,values|
      mainFile = values["file"]
      mainFile = mainFile[0,mainFile.rindex("_arms")]
      #p mainFile
      if ( ret = @hddSkins.find { |k,v| v["file"] == mainFile+".mdl" } ) != nil
        #p "Found arms for this model: " + ret.to_s
        ret[1]["arms"] = values["file"]
        ret[1]["armspath"] = values["path"]
    values["matched"] = true
      end
    end
    @hddArms.delete_if { |k,v| v["matched"] != nil }
    p "Remaining arms: "
    p @hddArms
  end

  def listModels(path="")
    listMDL ( @serverPath + "/" + @modelsPath), "", @serverPath + "/" 
    listMDL ( @serverPath + "/" + @materialsPath), "", @serverPath + "/" 
    joinArms
  end
  
  def openDatabase
    db = Mysql.new( @storeDBHost, @storeDBUser, @storeDBPass, @storeDBName )   
  end
  
  def loadModels(db)
    # as hash is actually default
    res = db.query("select id,name,attrs from store_items where type = 'skin'")
    databaseSkins = Hash.new
    res.each do |entry|
      #p entry
      json = JSON.parse(entry[2])
      @databaseSkins[entry[1]] = { "id" => entry[0], "model" => json["model"], "arms" => json["arms"] }
      #binding.pry
    end
    #binding.pry
    db
  end

  def mergeHDDDatabase(db)
    @databaseSkins.each do |k,values|
      #if k.include? "pink_panther"
      #  binding.pry
      #end
      file = values["model"]
      if (ret = @hddSkins.find { | k,v | (v["filepath"]+"/"+v["file"]) == file } ) != nil 
        #p "Found HDD representation of database: " + file
        ret[1]["present"] = true
        values["present"] = true
    #binding.pry
        if ret[1]["arms"] != nil && ret[1]["armspath"] != nil 
          if values["arms"] != nil && values["arms"] != ret[1]["armspath"] +"/"+ ret[1]["arms"] 
            #binding.pry
            values["arms"] = ret[1]["arms"]
            ret[1]["modified"] = true
          end
          #p "Arms added"
        end
      end
    end
    p "Skins needed to be updated in database"
    pp (@updateEntries = @hddSkins.select { |k,v| v["modified"] != nil })
    
    @hddSkins.delete_if { |k,v| v["modified"] == nil && v["present"] != nil }
    p "Skins not in database:" 
    pp @hddSkins
    p "Skins missing from hdd:"
    pp (@deleteSkins = @databaseSkins.select { |k,v| v["present"] == nil })

    # Resolve name conflicts right away
    @hddSkins.each do |k,values|
      values["name"] = k
      loop do
        if ( (@databaseSkins.select { |k,v| v == values["name"] }).empty? )
          break
        end
        binding.pry
        values["name"] = values["name"] + "_"
      end
    end
    updateDBSkins( db, @updateEntries, @hddSkins, @deleteSkins )
  end

  def mergeModels(db)
    loadModels(db)
    listModels
    mergeHDDDatabase(db)
  end
  
  def getSkinsCategoryFromDB(db)
    sqlFindCategory = "select id from store_categories where require_plugin='skin'"
    res = db.query(sqlFindCategory)
    skin_category = nil
    begin 
    skin_category = res.fetch_row[0]
    rescue
      p "Failed to retrieve 'skin' category from database"
      return nil
    end
    skin_category
  end
  
  def deleteSkinsFromDB(db)
     skin_category = getSkinsCategoryFromDB(db)
     if skin_category == nil
       return 0
     end
     
     sqlDeleteAllSkins = "delete from store_items where category_id = ?" 
     stmt = db.prepare sqlDeleteAllSkins  
     stmt.execute skin_category
  end

  def updateDBSkins( db, updateEntries = {}, addEntries = {}, deleteEntries = {} )
    #binding.pry
    sqlUpdateSkin = "update store_items set name=?, attrs=? where id=?"
    sqlInsertSkin = "insert into store_items(name,display_name,type,loadout_slot,category_id,attrs) values(?,?,?,?,?,?)"
    sqlDeleteSkin = "delete from store_items where id=?"

    skin_category = getSkinsCategoryFromDB(db)
    if skin_category == nil
      return 0
    end

    stmt = db.prepare sqlDeleteSkin 
    deleteEntries.each do |k,values|
      p "Deleting from database: " + k
      begin
        stmt.execute values["id"]
      rescue
      end
    end

    stmt = db.prepare sqlUpdateSkin 
    updateEntries.each do |k,values|
      p "Updating in database: " + k
      arms = String.new
      if values["armspath"] != nil && values["arms"] != nil 
        arms = values["armspath"] + "/" + values["arms"]
      end
      jsonHash = { "model" => values["filepath"] + "/" + values["file"], "arms" => arms, "teams" => [ 2, 3]  }
      begin
        stmt.execute k, JSON.pretty_generate(jsonHash), values["id"] 
      rescue
      end
    end

    stmt = db.prepare sqlInsertSkin 
    addEntries.each do |k,values|
      arms = String.new
      #binding.pry
      if values["armspath"] != nil && values["arms"] != nil 
        arms = values["armspath"] + "/" + values["arms"]
      end
      jsonHash = { "model" => values["filepath"] + "/" + values["file"], "arms" => arms, "teams" => [ 2, 3] }
      begin
        stmt.execute "skin_"+values["name"], values["name"], "skin", "skin", skin_category, JSON.pretty_generate(jsonHash)
      rescue
      end
    end
  end

  def loadTrails

  end
  
  def entry
    options = {}
    OptionParser.new do |opts|
      opts.banner = "Usage: " + File.basename(__FILE__) +" [options]"
    
      opts.on("-u", "--unpack", "unpack map bz2 files") do |u|
        options[:unpack] = u
      end
      
      opts.on("-p", "--pack", "pack map bz2 files") do |pa|
        options[:pack] = pa
      end
      
      opts.on("-e", "--existing", "do not unpack/pack files of which the map/archive file already exists") do |e|
        options[:existing] = e
      end
      
      opts.on("-l", "--list", "print a maplist.txt file according to the current maps") do |ml|
        options[:maplist] = ml
      end
      
      opts.on("-c", "--cycle", "create a umc mapcycle and print the umc cycle as well as the map cycle, uses ckSurf db to resolve tiers and stages") do |mc|
        options[:mapcycle] = mc
      end
      
      opts.on("-d", "--drop_skins", "delete all skins from the database") do |ds|
        options[:dropskins] = ds
      end
      
      opts.on("-i", "--import_skins", "import skins to the database from the mods/materials folder") do |is|
        options[:importskins] = is
      end
    end.parse!

   
    if options[:unpack] == true 
      if options[:existing] == true
        unpack(true)
      else
        unpack
      end
    end
    
    if options[:pack] == true 
      if options[:existing] == true
        pack(true)
      else
        pack
      end
    end
    
    maplist = nil
    if options[:maplist] == true 
      maplist = createMapList
    end
    
    mapcycle = nil
    if options[:mapcycle] == true 
      if maplist == nil
        maplist = createMapList(false)
      end
      createUMCList(maplist)
    end
    
    database = nil
    
    if options[:dropskins] == true 
      db = openDatabase
      deleteSkinsFromDB(db)
    end
    
    if options[:importskins] == true 
      if db == nil
        db = openDatabase
      end
      mergeModels(db)
    end
    
    
  end

end

MapEntries.new.entry