path=/home/surf/surf_patch

rm -rf ${path}
mkdir -p ${path}

mkdir -p ${path}/csgo/addons
cp -Rv csgo/addons/ ${path}/csgo
mkdir -p ${path}/csgo/cfg 
cp -Rv csgo/cfg/ ${path}/csgo
mkdir -p ${path}/csgo/materials 
cp -Rv csgo/materials/ ${path}/csgo
mkdir -p ${path}/csgo/models 
cp -Rv csgo/models/ ${path}/csgo
mkdir -p ${path}/csgo/sound 
cp -Rv csgo/sound/ ${path}/csgo
cp -Rv csgo/gamemodes.txt ${path}/csgo/
cp -Rv csgo/gamemodes_server.txt ${path}/csgo/
cp -Rv *.sh ${path}
cp -Rv *.rb ${path}	
cp readme ${path}



sed -i 's/^\(sv_setsteamaccount \).*/\1\"replaceMe\"/' ${path}/csgo/cfg/server.cfg
sed -i 's/^\(hostname \).*/\1\"Your awesome surf server\"/' ${path}/csgo/cfg/server.cfg
sed -i 's/^\(sv_downloadurl \).*/\1\"your fastdownload IP here\"/' ${path}/csgo/cfg/server.cfg
sed -i 's/^\(rcon_password \).*/\1\"ChangeMe\"/' ${path}/csgo/cfg/server.cfg

sed -i -re 's/(\s+\"host\"\s+).*/\1\"replaceMe\"/' ${path}/csgo/addons/sourcemod/configs/databases.cfg
sed -i -re 's/(\s+\"pass\"\s+).*/\1\"\"/' ${path}/csgo/addons/sourcemod/configs/databases.cfg

sed -i -re 's/(\s+@storeDBHost =\s+).*/\1\"replaceMe\"/' ${path}/adminTool.rb
sed -i -re 's/(\s+@storeDBPass =\s+).*/\1\"replaceMe\"/' ${path}/adminTool.rb

rm ../surf_server.zip
zip -r ../surf_server.zip ${path}
