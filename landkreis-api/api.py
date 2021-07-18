import json
from flask import Flask, request
app = Flask(__name__)

landkreis_file = open("landkreise.json", "r")
landkreis_data = json.load(landkreis_file)

def ags_from_name(query):
	if not query:
		return {"error": " Kein Landkreis angegeben!"}
	for item in landkreis_data:
		if query in item['Kreisfreie Stadt, Kreis/Landkreis']:
			print(item)
			return item['AGS']
	return {"error": " Kein Landkreis gefunden!"}


@app.route('/landkreise/ags', methods=['GET'])
def landkreise():
	query = request.args.get('name', None)
	return json.dumps(ags_from_name(query))

app.run()
