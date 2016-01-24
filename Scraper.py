#!/usr/bin/python
# -*- coding: utf-8 -*-


#Den Quellcode liest wenn dan eh nur Max. Das ist mein zweites Python programm dieses Jahr. Also lass mich in ruh :D

import sys, re, socket, string, time
import requests

from bs4 import BeautifulSoup, SoupStrainer



def scrapeAll(startPage, url):
	maxPageCount = 314
        for i in range(int(startPage),maxPageCount+1,1):
		url = 'http://interfacelift.com/wallpaper/downloads/date/any/index' + str(i) + '.html'
		headers = { 'User-Agent' : 'Mozilla/5.0 (Windows NT 6.1; rv:11.0) Gecko/20100101 Firefox/11.0' };
		print url
		content = requests.get(url, headers=headers).text
		#print content
		#print resp.cookies
		strainer = SoupStrainer( 'div', attrs={ 'id':'wallpaper' } )
        	soup = BeautifulSoup(content,parse_only=strainer)
		resolutionVar = '1920x1080'
		
		for a in soup.findAll( 'div', { 'id' : re.compile('list_*') } ):
			javaScriptCall = a.find( 'select', { 'class' : 'select' } ).get('onchange')
			#javascript:imgload('jeffersoninthemorning', this,'3437')

			firstLiteral = string.find( javaScriptCall, '\'', 0, len(javaScriptCall) )
			secondLiteral = string.find( javaScriptCall, '\'', firstLiteral+1, len(javaScriptCall) )
			
			thirdLiteral = string.find( javaScriptCall, '\'', secondLiteral+1, len(javaScriptCall) )

			fourthLiteral = string.find( javaScriptCall, '\'', thirdLiteral+1, len(javaScriptCall) )

			pictureName = (javaScriptCall[firstLiteral+1:secondLiteral])
			pictureID = (javaScriptCall[thirdLiteral+1:fourthLiteral])
			
			

			while( len(pictureID) < 5 ):
				pictureID = '0' + pictureID

			downloadUrl = 'http://www.interfacelift.com/wallpaper/7yz4ma1/'+pictureID+'_'+pictureName+'_'+resolutionVar+'.jpg'

			print downloadUrl
			

			with open(pictureName + '.jpg', 'wb') as handle:
    				request = requests.get(downloadUrl, allow_redirects=True, headers=headers, stream=True)

    				for block in request.iter_content(1024):
        				if not block:
            					break

        				handle.write(block)
			time.sleep(2)
	return 0

scrapeAll(sys.argv[1], 'http://interfacelift.com/wallpaper/downloads/date/index1.html')

