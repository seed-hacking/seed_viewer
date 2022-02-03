// still a few setAttribute calls to fix

var keggmaps = new Array();
var numkeggmaps = 0;
var reactions = new Array();
var numreactions = 0;
var compounds = new Array();
var numcompounds = 0;
var models = new Array();
var nummodels = 0;
var loadedMaps = new Array();
var MVTables = new Array();
var mapTabIndex = 2;
var objectMapIndex = 1;
var selectedModels = new Array();
var modelIds = new Array();

// COLORS - color information used for models

var colors = ["6495ED", "B23636", "3CB371", "CD853F", "00FFFF"];

colors['gapfill'] = "800080";
colors['biomass'] = "00FF00";
colors['transport'] = "FF0000";
colors['represented'] = "0000FF";

var colorBoxes = ["data:image/gif;base64,iVBORw0KGgoAAAANSUhEUgAAAAwAAAAMAQMAAABsu86kAAAAA1BMVEVkle06Kb68AAAAC0lEQVQImWNgIAwAACQAAa5tRrMAAAAASUVORK5CYII=", "data:image/gif;base64,iVBORw0KGgoAAAANSUhEUgAAAAwAAAAMAQMAAABsu86kAAAAA1BMVEWyNjYnBhNIAAAAC0lEQVQImWNgIAwAACQAAa5tRrMAAAAASUVORK5CYII=", "data:image/gif;base64,iVBORw0KGgoAAAANSUhEUgAAAAwAAAAMAQMAAABsu86kAAAAA1BMVEU8s3Fi4Z3/AAAAC0lEQVQImWNgIAwAACQAAa5tRrMAAAAASUVORK5CYII=", "data:image/gif;base64,iVBORw0KGgoAAAANSUhEUgAAAAwAAAAMAQMAAABsu86kAAAAA1BMVEXNhT/On3n6AAAAC0lEQVQImWNgIAwAACQAAa5tRrMAAAAASUVORK5CYII=", "data:image/gif;base64,iVBORw0KGgoAAAANSUhEUgAAAAwAAAAMAQMAAABsu86kAAAAA1BMVEUA//8ZXC8lAAAAC0lEQVQImWNgIAwAACQAAa5tRrMAAAAASUVORK5CYII="];

colorBoxes['gapfill'] = "data:image/gif;base64,iVBORw0KGgoAAAANSUhEUgAAAAwAAAAMAQMAAABsu86kAAAAA1BMVEWAAICr96V6AAAAC0lEQVQImWNgIAwAACQAAa5tRrMAAAAASUVORK5CYII=";
colorBoxes['biomass'] = "data:image/gif;base64,iVBORw0KGgoAAAANSUhEUgAAAAwAAAAMAQMAAABsu86kAAAAA1BMVEUA/wA0XsCoAAAAC0lEQVR4nGNgIAwAACQAAbZm3wQAAAAASUVORK5CYII=";
colorBoxes['transport'] = "data:image/gif;base64,iVBORw0KGgoAAAANSUhEUgAAAAwAAAAMAQMAAABsu86kAAAAA1BMVEX/AAAZ4gk3AAAAC0lEQVR4nGNgIAwAACQAAbZm3wQAAAAASUVORK5CYII=";
colorBoxes['represented'] = "data:image/gif;base64,iVBORw0KGgoAAAANSUhEUgAAAAwAAAAMAQMAAABsu86kAAAAA1BMVEUAAP+KeNJXAAAAC0lEQVR4nGNgIAwAACQAAbZm3wQAAAAASUVORK5CYII=";


// TESTING URL EVENTS FUNCTIONHANDLER

// SELECTED MODELS - functions involved with the selection/removal of models

function addModelLoadingRow (modelId) {
	var table = document.getElementById('selected_model_table');
	table.style.display = '';
	
	var row = table.tBodies[0].appendChild(document.createElement('tr'));
	row.id = 'model_loading_'+modelId;
	var imgTd = row.appendChild(document.createElement('td'));
	imgTd.innerHTML = "<img src='./Html/ajax-loader.gif' height='16px' width='16px' />";
	var nameTd = row.appendChild(document.createElement('td'));
	nameTd.innerHTML = modelId;
}

function addModelRow (model) {
	var table = document.getElementById('selected_model_table');
	var row = document.getElementById('model_loading_' + model.ID);
	var rowHtml = "<td></td><td>"+model.ID+"</td><td>"+model.NAME+"<br>("+genomeLink(model.GENOME)+")"+"</td><td>V"+model.VERSION+"</td><td>";
	rowHtml = rowHtml+model.SOURCE+"</td><td>"+model.SIZE+"</td><td>"+model.MDLGENECOUNT+"<br>/"+model.GENOMEGENECOUNT+"</td><td>";
	var gfrxn = model.RXNCOUNT-model.RXNWITHGENES;
	rowHtml = rowHtml+model.RXNWITHGENES+"<br>/"+model.RXNCOUNT+"</td><td>"+gfrxn+"<br>/"+model.RXNCOUNT+"</td><td>"+model.ACMEDIA+"</td><td>";
	rowHtml = rowHtml+model.CPDCOUNT+"</td><td></td>";
	row.innerHTML = rowHtml;
	var closeTd = row.appendChild(document.createElement('td'));
	var closeImg = closeTd.appendChild(document.createElement('img'));
	closeImg.src = './Html/delete-red.png';
	closeImg.width = 16;
	closeImg.height = 16;
	closeImg.style.cssText = 'cursor:pointer;';
	closeImg.title = "Remove model";
	closeImg.onclick = function() {
		table.tBodies[0].removeChild(row);
		if (table.rows.length == 1) table.style.display = 'none';
			updateModelRowColors();
		removeModel(model);
	};
	updateModelRowColors();
}

function addModel(eventString, modelId) {
	addModelRow(models[modelId]);
	updateKeggTab();
	addModelReactions(modelId);
	addModelCompounds(modelId);
    var request = {
        name: "getFBAControls",
        target: "mfbaControls",
        type: "server",
        sub: "outputFluxControls",
        component: "MFBAController|mfba_controller",
        cgi_params: 'model=' + models.join(','),
    };
    Ajax.createRequest(request); 
	AjaxQueue.add(request.name, 1);
	AjaxQueue.start();
}

function removeModel (model) {
	delete selectedModels[model.ID];
	var index = modelIds.indexOf(model.ID);
	if (index != -1) modelIds.splice(index, 1);
		delete modelIds[index];
	
	updateKeggTab();
	MVTables['rxnTable'].removeColumn(model.ID);
	MVTables['cpdTable'].removeColumn(model.ID);
	EM.raiseEvent("RemoveModel", model.ID);
}

function updateModelRowColors () {
	var table = document.getElementById('selected_model_table');
	
	var rows = table.tBodies[0].rows;
	for (var i=1; i<rows.length; i++) {
		// skip if model is still loading
		if (models[rows[i].cells[1].innerHTML] != 0) {
			rows[i].cells[0].innerHTML = "<img src='" + colorBoxes[i-1] + "' />";
		}
	}
}

//Utility functions - generic functions useful in multiple elements throughout the page

function load_html_from_cache(filedata) {
	var strings = filedata.split("\n");
	if (strings.length > 0) {
		var object = document.getElementById(strings[0]);
		if (object) {
			var htmlText = "";
			for (var i=1; i<strings.length; i++) {
				htmlText = htmlText + strings[i];
			}
			object.innerHTML = htmlText; 
		}
	}
}

// PAGE EVENTS - functions called on user interaction with the page

function select_maps_from_id(id) {
	var object;
	if (id.substr(0,3) == "cpd") {
		object = compounds[id];
	} else if (id.substr(0,3) == "rxn") {
		object = reactions[id];
	}
	for (var i=0; i<loadedMaps.length; i++) {
		var tdObject = document.getElementById(mapTabIndex+"_tab_"+i);
		if (tdObject && tdObject.className == "tab_view_title_selected_highlighted") {
			tdObject.className = "tab_view_title_selected";
		} else if (tdObject && tdObject.className == "tab_view_title_highlighted") {
			tdObject.className = "tab_view_title";
		}
	}
	for (var i=0; i<object.KEGG_MAPS.length; i++) {
		loadKeggMap(object.KEGG_MAPS[i],0,id);
	}
	for (var i=0; i<object.KEGG_MAPS.length; i++) {
		var mapIndex = loadedMaps.indexOf(object.KEGG_MAPS[i]);
		var tdObject = document.getElementById(mapTabIndex+"_tab_"+mapIndex);
		if (tdObject && tdObject.className == "tab_view_title_selected") {
			tdObject.className = "tab_view_title_selected_highlighted";
		} else if (tdObject && tdObject.className == "tab_view_title") {
			tdObject.className = "tab_view_title_highlighted";
		}
	}
	tab_view_select(objectMapIndex,0);
}

function initializeEvents() {
	EM.addEvent("SelectModel", addModel);
}

// passthrough function
function select_model (input) {
	selectModel(input);
	var tabId = document.getElementById('tabViewOverview').value;
	tab_view_select(tabId, 0);
}

// selects a model
function selectModel (input) {
	var NewModel;
	if (input.substr(0,6) == "select") {
		NewModel = document.getElementsByName(input)[0].value;
	} else {
		if (input.length > 0) {
			NewModel = input;
		} else {
			NewModel = document.getElementById('filter_select_1').value;
		}
	}
	//Checking if the model is already selected
	if (selectedModels[NewModel]) {
		// inform that model is loaded already
		customAlert('Model has already been selected!');
		return;
	}
	//Checking if the model exists and is accessible
	if (models[NewModel] == null) {
		customAlert('Selected model does not exist or is not accessible to user!');
		return;
	}
	//Adding the model to the selected model list
	selectedModels[NewModel] = 1;
	var model = models[NewModel];
	modelIds.push(NewModel);
	addModelLoadingRow(NewModel);
	var name = "selectModel_" + NewModel;
	if (!Ajax.getRequest(name)) {
		var request = {
			name: "selectModel_" + NewModel,
			type: "server",
			sub: "get_model_info",
			cgi_params: 'model='+NewModel,
			onfinish: function() {EM.raiseEvent("SelectModel", NewModel);}
		};
		Ajax.createRequest(request);
	}
	AjaxQueue.add(name, 1);
	AjaxQueue.start();
	return;
}

// load kegg maps into a new tab, or reload the tab if selected models change
function loadKeggMap (mapId, forceReload, id) {
	var keggmap = keggmaps[mapId];
	var name = keggmap.NAME;	
	var param = "pathway=" + mapId;
	 // used to map keggid to compounds and reactions
	var keggMappings = new Array();
	var rxnColorArray = new Array();
	var cpdColorArray = new Array();
	// loop through reactions
	if (keggmap.REACTIONS) {
		for (var i=0; i<keggmap.REACTIONS.length; i++) {
			var reaction = keggmap.REACTIONS[i];
			// first get keggid mappings
			var keggids = reactions[reaction].KEGGID;
			for (var j=0; j<keggids.length; j++) {
				keggMappings[keggids[j]] = reaction;
			}
			var rxnColors = new Array();
			for (var j=0; j<modelIds.length; j++) {
				var model = models[modelIds[j]];
				if (model != 0) {
					var modelReaction = model.REACTIONS[reaction];
					if (modelReaction) {
						// check if any gapfilled genes
						var gapfilled = 0;
						if (modelReaction.PEGS) {
							// loop through pegs
							var reg = new RegExp("peg", "i");
							for (var k=0; k<modelReaction.PEGS.length; k++) {
								if (!modelReaction.PEGS[k].match(reg)) {
									gapfilled = 1;
									break;
								}
							}
						} else {
							gapfilled = 1;
						}
						if (gapfilled) {
							rxnColors.push(modelIds.length);
						} else {
							rxnColors.push(j);
						}
					}
				}
			}
			if (rxnColors.length > 0) {
				// change to kegg id
				var keggids = reactions[reaction].KEGGID;
				for (var j=0; j<keggids.length; j++) {
					rxnColorArray.push(keggids[j] + "," + rxnColors.join(","));
				}
			}
		}
	}

	// loop through compounds
	if (keggmap.COMPOUNDS) {
		for (var i=0; i<keggmap.COMPOUNDS.length; i++) {
			var compound = keggmap.COMPOUNDS[i];
			// first get keggid mappings
			var keggids = compounds[compound].KEGGID;
			for (var j=0; j<keggids.length; j++) {
				keggMappings[keggids[j]] = compound;
			}
			var cpdColors = new Array();
			for (var j=0; j<modelIds.length; j++) {
				var model = models[modelIds[j]];
				if (model != 0) {
					var modelCompound = model.COMPOUNDS[compound];
					if (modelCompound) {
						if (modelCompound.BIOMASS) {
							cpdColors.push(0);
						} else if (modelCompound.TRANSPORT) {
							cpdColors.push(1);
						} else {
							cpdColors.push(2);
						}
					}
				}
			}
			if (cpdColors.length > 0) {
				// change to kegg id
				var keggids = compounds[compound].KEGGID;
				for (var j=0; j<keggids.length; j++) {
					cpdColorArray.push(keggids[j] + "," + cpdColors.join(","));
				}
			}
		}
		if (modelIds.length > 0) {
			param += "&num_models=" + modelIds.length;
			param += "&reactions=" + rxnColorArray.join("|");
			param += "&compounds=" + cpdColorArray.join("|");
		}
	}
	// messy javascript calls
	var onclose = "(function () {var index = loadedMaps.indexOf('" + mapId + "'); if (index != -1) loadedMaps.splice(index,1);})";
	var post_hook = function () {createMapAreas(mapId, keggMappings)};
	addTab(mapId, name, 'tabViewKeggMaps', 'get_kegg_map', param, forceReload, 0, onclose, post_hook);
	if (loadedMaps.indexOf(mapId) == -1) loadedMaps.push(mapId);
}

function createMapAreas (mapId, keggMappings) {
	// eval the returned hidden mapinfo structure
	var mapInfoInput = document.getElementById('mapInfo_'+mapId);
	if (mapInfoInput) {
		var mapInfo = eval('(' + mapInfoInput.value + ')');
		var keggmap = document.getElementById('keggmap_'+mapId);
		var imgMap = keggmap.getElementsByTagName('map')[0];

		// create areas for reactions
		for (var keggRxn in mapInfo.rxnCoords) {
			var rxnCoordArray = mapInfo.rxnCoords[keggRxn];
			for(var i=0; i<rxnCoordArray.length; i++) {
				var rxnCoords = rxnCoordArray[i];
				var area = document.createElement('area');
				area.setAttribute('shape', 'rect'); // area.shape?
				area.setAttribute('coords', rxnCoords.join(",")); //area.coords?
				if (keggMappings[keggRxn]) {
					area.href = "javascript:reactionPopup('" + keggMappings[keggRxn] + "')";
					area.onmouseover = function(id) {
						return function(e) {
							reactionHover(e, id);
						};
					}(keggMappings[keggRxn]);
					imgMap.appendChild(area);
				} else {
					// let user know not available, this shouldn't be happening...
					// lots of unavailable reactions in Arginine and proline metabolism map
				}
			}
		}

		// create areas for compounds
		for (var keggCpd in mapInfo.cpdCoords) {
			var cpdCoordArray = mapInfo.cpdCoords[keggCpd];
			for(var i=0; i<cpdCoordArray.length; i++) {
				var cpdCoords = cpdCoordArray[i];
				var area = document.createElement('area');
				area.setAttribute('shape', 'rect');
				area.setAttribute('coords', cpdCoords.join(","));
				if (keggMappings[keggCpd]) {
					area.href = 'javascript:compoundPopup("' + keggMappings[keggCpd] + '")';
					area.onmouseover = function(id) {
						return function(e) {
							compoundHover(e, id);
						};
					}(keggMappings[keggCpd]);
					imgMap.appendChild(area);
				} else {
					// let user know not available
				}
			}
		}

		// create areas for other maps
		for (var keggMap in mapInfo.mapCoords) {
			// check if the map data is available
			if (keggmaps[keggMap]) {
				var mapCoordArray = mapInfo.mapCoords[keggMap];
				for (var i=0; i<mapCoordArray.length; i++) {
					var mapCoords = mapCoordArray[i];
					var area = document.createElement('area');
					area.setAttribute('shape', 'rect');
					area.setAttribute('coords', mapCoords.join(","));
					area.href = 'javascript:loadKeggMap("' + keggMap + '")';
					imgMap.appendChild(area);
				}
			} else {
				// let user know not available
			}
		}
	}
}

function reactionHover (event, rxnId) {
	var hoverId = document.getElementById('keggMapHover').value;
	var hoverSpan = document.getElementById('tooltip_' + hoverId + '_current');
	if (hoverSpan.name != rxnId) {
		hoverSpan.name = rxnId;
 		hoverSpan.innerHTML = createRxnInfo(rxnId, 0);
	}
	hover(event, "current", hoverId);
	return false;
}

function compoundHover (e, cpdId) {
	var hoverId = document.getElementById('keggMapHover').value;
	var hoverSpan = document.getElementById('tooltip_' + hoverId + '_current');
	if (hoverSpan.name != cpdId) {
		hoverSpan.name = cpdId;
 		hoverSpan.innerHTML = createCpdInfo(cpdId, 0);
	}
	hover(e, "current", hoverId);
}

function reactionPopup (rxnId) {
	var popupDiv = document.getElementById('keggmap_popup');
	if (popupDiv.name != rxnId) {
		popupDiv.name = rxnId;
		popupDiv.innerHTML = createRxnInfo(rxnId, 1);
	}
	popUp('keggmap_popup');
}

function compoundPopup (cpdId) {
	var popupDiv = document.getElementById('keggmap_popup');
	if (popupDiv.name != cpdId) {
		popupDiv.name = cpdId;
		popupDiv.innerHTML = createCpdInfo(cpdId, 1);
	}
	popUp('keggmap_popup');
}

function createRxnInfo (rxnId, popup) {
	var reaction = reactions[rxnId];
	if (reaction) {
		var rxnHtml = "<p><b>Reaction " + reactionLink(rxnId) + "</b>";
		if (reaction.NAME) {
			rxnHtml += "<br />" + reaction.NAME[0];
		}
		rxnHtml += "</p><p><b>KEGG ID:</b><br />";
		if (popup) {
			var keggLinks = new Array();
			for (var i=0; i<reaction.KEGGID; i++) {
				keggLinks.push(keggReactionLink(reaction.KEGGID[i]));
			}
			rxnHtml += keggLinks.join(", ");
		} else {
			rxnHtml += reaction.KEGGID.join(", ");
		}
		rxnHtml += "</p><p><b>Equation:</b><br />" + reactionEquationLinks(reaction.EQUATION) + "</p>";
	
		if (popup) {
			rxnHtml += "<p><b>Enzyme(s):</b><br />";
			if (reaction.ENZYME) {
				rxnHtml += "<ul style='margin-left:-15px'>";
				for (var i=0; i<reaction.ENZYME.length; i++) {
					rxnHtml += "<li>" + enzymeLink(reaction.ENZYME[i]) + "</li>";
				}
				rxnHtml += "</ul></p>";
			} else {
				rxnHtml += "&nbsp;&nbsp;&nbsp;None</p>";
			}
	
			rxnHtml += "<p><b>Functional Roles:</b><br />";
			if (reaction.ROLES) {
				rxnHtml += "<ul style='margin-left:-15px'>";
				for (var i=0; i<reaction.ROLES.length; i++) {
					rxnHtml += "<li>" + reaction.ROLES[i] + "</li>";
				}
				rxnHtml += "</ul></p>";
			} else {
				rxnHtml += "&nbsp;&nbsp;&nbsp;None</p>";
			}
	
			rxnHtml += "<p><b>Subsystems:</b><br />";
			if (reaction.SUBSYSTEMS) {
				rxnHtml += "<ul style='margin-left:-15px'>";
				for (var i=0; i<reaction.SUBSYSTEMS.length; i++) {
					rxnHtml += "<li>" + subsystemLink(reaction.SUBSYSTEMS[i]) + "</li>";
				}
				rxnHtml += "</ul></p>";
				
			} else {
				rxnHtml += "&nbsp;&nbsp;&nbsp;None</p>";			
			}
		}
		
		for (var i=0; i < modelIds.length;i++) { 
			var rxn = models[modelIds[i]].REACTIONS[rxnId];
			if (rxn) {
				rxnHtml += "<b>"+modelIds[i]+" model:</b><br>";
				rxnHtml += "<ul style='margin-left:-15px'>";
				for (var j=0; j < rxn.PEGS.length;j++) {
					rxnHtml += "<li>"+pegLinks(rxn.PEGS[j],modelIds[i])+"</li>";
				}
				for (var j=0; j < rxn.CLASSES.length;j++) {
					rxnHtml += "<li>"+rxn.CLASSES[j].CLASS+"</li>";
				}
			}
		}
		
	}
	return rxnHtml;
}

// function that splits equation compounds into names, and creates links if link
function createCpdInfo (cpdId, popup) {
	var compound = compounds[cpdId];

	var cpdHtml = "<p><b>Compound " + cpdId + "</b><br />";
	cpdHtml += compound.NAME.join("<br />");
	cpdHtml += "</p><p><b>" + compound.FORMULA + "</b></p>";
	cpdHtml += "<p><b>KEGG ID:</b><br />";
	if (popup) {
		var keggLinks = new Array();
		for (var i=0; i<compound.KEGGID; i++) {
			keggLinks.push(keggCompoundLink(compound.KEGGID[i]));
		}
		cpdHtml += keggLinks.join(", ");
	} else {
		cpdHtml += compound.KEGGID.join(", ");
	}
	cpdHtml += "</p><p><b>Charge:&nbsp;&nbsp;</b>";

	return cpdHtml;
}

// TABLE - functions that allow data to be loaded dynamically into toby tables

function createMVTable (table) {
	var mvtable = new MVTable(table);
	MVTables[mvtable.name] = mvtable;
}

// store the table name, column names, and row ids.
// get the data through the Table web component
// note that this does not actually create the table, but loads
// data into a table that's been created from Table.pm
function MVTable (mvtable) {
	// first create table object to store data
	var tableId = document.getElementById(mvtable.name).value;
	this.id = tableId;
	this.name = mvtable.name;
	this.columns = mvtable.columns;
	this.sub = mvtable.subroutine;
	this.div = mvtable.div;

	this.setColumnIds();
}

MVTable.prototype.setColumnIds = function () {
	var columnIds = new Array();
	for (var i=0; i<this.columns.length; i++) {
		columnIds[this.columns[i].name] = i;
	}
	this.columnIds = columnIds;
}

MVTable.prototype.setData = function (data, rowIds) {
	var table = document.getElementById('table_'+this.id);

	var rows = new Array();
	for (var i=0; i<rowIds.length; i++) {
		rows[rowIds[i]] = data[i];
		data[i].push(i);
	}

	this.data = data;
	this.rows = rows;
	this.numRows = rowIds.length;

	this.reload();
}

MVTable.prototype.reload = function () {
	initialize_table(this.id, this.data);
}

MVTable.prototype.getRow = function (rowId) {
	return this.rows[rowId];
}

MVTable.prototype.getCell = function (rowId, columnId) {
	var colIndex = this.columns[columnId];
	return this.rows[rowId][colIndex];
}

MVTable.prototype.updateRow = function (row, rowId) {
	this.rows[rowId] = row;
	this.data[rowIndex] = row;
	this.reload();
}

MVTable.prototype.updateCell = function (cell, rowId, columnId) {
	var colIndex = this.columns[columnId];
	this.row[rowId][colIndex] = cell;
	this.reload();
}

MVTable.prototype.addRow = function (row, data, index) {
	// Add row and reload data
	if (index == null) {
		index = this.numRows;
	}

	data.push(index);
	this.rows[row] = data;
	this.data.splice(index, 0, data);

	this.numRows++;
	this.incrementRowIds(index+1);

	// reload table
	this.reload();
}

MVTable.prototype.removeRow = function (rowId) {
	var index = this.rows[rowId][this.columns.length];
	delete this.rows[rowId];
	this.data.splice(index, 1);

	this.numRows--;
	this.decrementRowIds(index);

	// reload table
	this.reload();
}

MVTable.prototype.incrementRowIds = function (index) {
	var end = this.columns.length;
	for (var i=index; i<this.numRows; i++) {
		this.data[i][end] += 1;
	}
}

MVTable.prototype.decrementRowIds = function (index) {
	var end = this.columns.length;
	for (var i=index; i<this.numRows; i++) {
		this.data[i][end] -= 1;
	}
}

MVTable.prototype.removeColumn = function (columnId) {
	// remove column
	var index = this.columnIds[columnId];
	if (index != null) {
		this.columns.splice(index, 1);

		// remove column data
		for (var i=0; i<this.data.length; i++) {
			this.data[i].splice(index, 1);
		}

		//reset the columnIds
		this.setColumnIds();

		// call ajax to reload columns
		this.reloadColumns();
	}
}

MVTable.prototype.addColumn = function (column, data, index) {
	// Add column, make ajax call to reload table, then add data
	if (index == null) {
		index = this.columns.length;
	}

	// construct column object
	column = this.checkColumn(column);

	if (column == null) {
		// alert user
		return;
	}

	this.columns.splice(index, 0, column);

	// now add the data
	for (var i=0; i<this.data.length; i++) {
		this.data[i].splice(index, 0, data[i]);
	}

	// reset the columnIds
	this.setColumnIds();	

	// call ajax to reload columns
	this.reloadColumns();
}

MVTable.prototype.addColumns = function (columns, data, index) {
	// Add columns, make ajax call to reload table, then add data
	if (index == null) {
		index = this.columns.length;
	}

	for (var i=0; i<columns.length; i++) {
		// construct column object
		var column = this.checkColumn(columns[i]);

		if (column == null) {
			// alert user
			return;
		}

		this.columns.splice(index, 0, column);

		// now add the data
		for (var j=0; j<this.data.length; j++) {
			this.data[j].splice(index, 0, data[i][j]);
		}

		index++;
	}

	// reset the columnIds
	this.setColumnIds();	

	// call ajax to reload columns
	this.reloadColumns();
}

MVTable.prototype.checkColumn = function (column) {
	if (typeof column != "object") {
		column = {
			name: column,
			filter: 1,
			sortable: 1
		}
	}

	if (this.columnIds[column.name]) {
		return null;
	}

	return column;
}

MVTable.prototype.reloadColumns = function () {
	var name = this.name;
	var reload = {
		subroutine: this.sub,
		columns: this.columns
	}

	var ajax = Ajax.getRequest("MVTableReload_" + name);
	if (ajax) {
		ajax.target = this.div;
		ajax.cgi_params = "mvtable=" + JSON.stringify(reload);
		ajax.onfinish = function() {reloadMVTable(name);};
	} else {
		ajax = {
			name: "MVTableReload_" + name,
			type: "server",
			sub: "MVTable_reload",
			target: this.div,
			cgi_params: "mvtable=" + JSON.stringify(reload),
			onfinish: function() {reloadMVTable(name);}
		}
		Ajax.createRequest(ajax);
	}

	Ajax.sendRequest("MVTableReload_" + name);
}

function reloadMVTable (tableName) {
	var mvtable = MVTables[tableName];
	if (mvtable) {
		mvtable.reload();
	}
}

/*
MVTable.prototype.addColumn = function (column, columnId) {
	var table = document.getElementById('table_'+this.id);

	index = this.numColumns;

	var td = table.rows[0].insertCell(index);
	td.id = this.id + '_col_' + (index);
	td.className = 'table_first_row';
	td.name = this.id + '_col_' + (index);

	var inner = "<a class='table_first_row' title='Click to sort' href='javascript:table_sort(\"" + this.id + "\", \"" + index + "\", \"ASC\");'>" + columnId + "</a>";

	td.innerHTML = inner;

	var input1 = td.appendChild(document.createElement('input'));
	input1.id = 'table_' + this.id + '_operator_' + (index);
	input1.type = 'hidden';
	input1.value = 'like';
	input1.name = this.id + '_col_' + (index) + '_operator';

	var input2 = td.appendChild(document.createElement('input'));
	input2.id = 'table_' + this.id + '_operand_' + (index);
	input2.className = 'filter_item';
	input2.type = 'text';

	// now add the data
	var data = this.data;
	for (var i=0; i<column.length; i++) {
		data[i][index] = column[i];
		data[i].push(i);
	}
}
*/

// LINK - functions used to create links for reactions, compounds, etc...

function reactionEquationLinks (equation) {
	var tempEquation = equation;
	var newEquation = "";
	for (var i = 0; i < tempEquation.length-7; i++) {
		if (tempEquation.substr(i,3) == "cpd") {
			newEquation = newEquation + tempEquation.substr(0,i) + compoundNameLink(tempEquation.substr(i,8));
			tempEquation = tempEquation.substr(i+8);
			i = -1;
		}
	}
	newEquation = newEquation + tempEquation;
	return newEquation;
}

function reactionLink (rxnId) {
	return '<a style="text-decoration:none" href="?page=ReactionViewer&reaction=' + rxnId + '" target="_blank">' + rxnId + "</a>";
}

function compoundLink (cpdId) {
	return '<a style="text-decoration:none" href="?page=CompoundViewer&compound=' + cpdId + '" target="_blank">' + cpdId + "</a>";
}

function compoundNameLink (cpdId) {
	if (compounds[cpdId] && compounds[cpdId].NAME[0]) {
		return '<a style="text-decoration:none" href="?page=CompoundViewer&compound=' + cpdId + '" target="_blank">' + compounds[cpdId].NAME[0] + "</a>";
	} else {
		return '<a style="text-decoration:none" href="?page=CompoundViewer&compound=' + cpdId + '" target="_blank">' + cpdId + "</a>";
	}
}

function keggReactionLink (keggId) {
	return '<a style="text-decoration:none" href="http://www.genome.jp/dbget-bin/www_bget?rn+' + keggId + '" target="_blank">' + keggId + "</a>";
}

function keggMapLink (id) {
	return '<a style="text-decoration:none" href="javascript:select_maps_from_id(\'' + id + '\');">View maps</a>';
}

function keggCompoundLink (keggId) {
	return '<a style="text-decoration:none" href="http://www.genome.jp/dbget-bin/www_bget?cpd:' + keggId + '" target="_blank">' + keggId + "</a>";
}

function enzymeLink (enzyme) {
	return '<a style="text-decoration:none" href="http://www.genome.jp/dbget-bin/www_bget?enzyme+' + enzyme + '" target="_blank">' + enzyme + "</a>";
}

function modelLink (model) {
	return '<a style="text-decoration:none" href="javascript:select_model(\'' + model + '\');">'+model+'</a>';
}

function genomeLink (genome) {
	return '<a style="text-decoration:none" href="?page=Organism&organism='+genome+'" target="_blank">'+genome+'</a>';
}

function pegLinks (pegs,model) {
	var mdl = models[model];
	if (mdl) {
		var newPegs = "";
		var pegList = pegs.split("+");
		for (var i=0; i < pegList.length; i++) {
			if (i>0) {
				newPegs = newPegs+" + ";
			}
			if (pegList[i].substr(0,4) != "peg.") {
				newPegs = newPegs+pegList[i];
			} else if (mdl.SOURCE.length > 4 && mdl.SOURCE.substr(0,4) == "RAST") {	
				newPegs = newPegs+'<a style="text-decoration:none" href="http://rast.nmpdr.org/rast.cgi?page=Annotation&feature=fig|'+mdl.GENOME+'.'+pegList[i]+'" target="_blank">'+pegList[i]+'</a>';
			} else {
				newPegs = newPegs+'<a style="text-decoration:none" href="?page=Annotation&feature=fig|'+mdl.GENOME+'.'+pegList[i]+'" target="_blank">'+pegList[i]+'</a>';
			}
		}
		return newPegs;
	}
	return pegs;
}

function sourceLink (source) {
	if (source.length > 4 && source.substr(0,4) == "PMID") {
		return '<a style="text-decoration:none" href="http://www.ncbi.nlm.nih.gov/pubmed/'+source.substr(4)+'">'+source+'</a>';
	}
	return source;
}

function subsystemLink (subsystem) {
	var re = new RegExp("_", "g");
    var NeatSubsystem = subsystem.replace(re, " ");
    subsystem = subsystem.replace(/\([\d\/]+\)$/,"");
	return '<a style="text-decoration:none" href="http://seed-viewer.theseed.org/seedviewer.cgi?page=Subsystems&subsystem=' + subsystem + '" target="_blank">' + NeatSubsystem + "</a>";
}

// UPDATE - functions used to update portions of the page

function updateKeggTab() {
	createKeggMapTable();
	updateModelKey();

	// reload kegg maps
	for (var i=0; i<loadedMaps.length; i++) {
		loadKeggMap(loadedMaps[i], 1);
	}

	// reset the hover
	var hoverId = document.getElementById('keggMapHover').value;
	document.getElementById('tooltip_' + hoverId + '_current').value = '';
}

function updateModelKey() {
	var modelKeyDiv = document.getElementById('modelKey');

	if (modelIds.length > 0) {
		var reactionCells = "<td><span style='font-weight:bold;'>Reactions:</span></td>";
		for (var i=0; i<modelIds.length; i++) {
			var model = models[modelIds[i]];
			if (model != 0) {
				var modelName = model.NAME + " (" + model.ID + ")";
				var modelNameSpan = "<span style='color: " + colors[i] + ";'>" + modelName + "</span>";
				reactionCells += "<td><img src='" + colorBoxes[i] + "' /></td><td>" + modelNameSpan + "</td>";
			}
		}
		reactionCells += "<td><img src='" + colorBoxes['gapfill'] + "' /></td><td><span style='color: " + colors['gapfill'] + ";'>Gapfilled</span></td>";

		var compoundCells = "<td><span style='font-weight:bold;'>Compounds:</span></td>";
		compoundCells += "<td><img src='" + colorBoxes['biomass'] + "' /></td><td><span style='color: " + colors['biomass'] + ";'>Biomass</span></td>";
		compoundCells += "<td><img src='" + colorBoxes['transport'] + "' /></td><td><span style='color: " + colors['transport'] + ";'>Transported</span></td>";
		compoundCells += "<td><img src='" + colorBoxes['represented'] + "' /></td><td><span style='color: " + colors['represented'] + ";'>Represented</span></td>";

		modelKeyDiv.innerHTML = "<table><tr>" + reactionCells + "</tr><tr>" + compoundCells + "</tr></table>";
	} else {
		modelKeyDiv.innerHTML = "";
	}
}

function createKeggMapTable () {
	var keggMapData = createKeggMapData();

	var mapTable = MVTables['mapTable'];
	mapTable.setData(keggMapData.data, keggMapData.ids);
}

function createReactionTable () {
	var reactionData = createRxnTableData();

	var reactionIds = new Array();
	for (var i=0; i<reactionData.length; i++) {
		reactionIds.push(reactionData[i][0]);
	}

	var rxnTable = MVTables['rxnTable'];
	rxnTable.setData(reactionData, reactionIds);
}

function createCompoundTable () {
	var compoundData = createCpdTableData();

	var compoundIds = new Array();
	for (var i=0; i<compoundData.length; i++) {
		compoundIds.push(compoundData[i][0]);
	}

	var cpdTable = MVTables['cpdTable'];
	cpdTable.setData(compoundData, compoundIds);
}

function createModelStatsTable () {
	var modelData = createModelStatsTableData();
	var modelIds = new Array();
	for (var i=0; i<modelData.length; i++) {
		modelIds.push(modelData[i][0]);
	}
	var modelTable = MVTables['mdlTable'];
	modelTable.setData(modelData, modelIds);
}

function createUserModelsTable () {
	var modelData = createUserModelsTableData();
	var modelIds = new Array();
	for (var i=0; i<modelData.length; i++) {
		modelIds.push(modelData[i][0]);
	}
	var modelTable = MVTables['usrmdlTable'];
	modelTable.setData(modelData, modelIds);
}

// add model column to reaction table
function addModelReactions (modelId) {
	// gather model reaction data
	var column = new Array();
	var model = models[modelId];
	for (reactionId in reactions) {
		var modelReaction = model.REACTIONS[reactionId];
		if (modelReaction) {
			var mrString = '';
			var classes = modelReaction.CLASSES;
			if (classes) {
				for (var j=0; j<classes.length; j++) {
					mrString += classes[j].CLASS + "<br />";
					if (classes[j].MINFLUX) {
						mrString += classes[j].MINFLUX + " to " + classes[j].MAXFLUX + "<br />";
					}
				}

				mrString += "<br />";
			}			
			var pegs = modelReaction.PEGS;
			if (pegs) {
				for (var j=0; j<pegs.length; j++) {
					mrString += pegs[j] + "<br />";
				}
			}

			if (modelReaction.NOTE && modelReaction.NOTE != 'NONE') {
				mrString += "<br />Note: " + modelReaction.NOTE;
			}

			column.push(mrString);
		} else {
			column.push('Not in model');
		}
	}
	
	// get MVTable and reload
	rxnTable = MVTables['rxnTable'];
	rxnTable.addColumn(modelId, column);
}

function addModelCompounds (modelId) {
	// gather model compound data
	var column = new Array();
	var model = models[modelId];
	for (compoundId in compounds) {
		var modelCompound = model.COMPOUNDS[compoundId];
		if (modelCompound) {
			column.push('yes');
		} else {
			column.push('no');
		}
	}

	// get MVTable and reload
	cpdTable = MVTables['cpdTable'];
	cpdTable.addColumn(modelId, column);
}

// function to update reaction table
function updateReactionTable () {
	var update = function() {
		var reactionData = createRxnTableData();
		var tableId = document.getElementById('rxnTable').value;
		initialize_table(tableId, reactionData);
	}

	execute_ajax('get_reaction_table', 'rxn_tab', 'model='+modelIds.join(","), '', '', update);
}

// function to update compound table
function updateCompoundTable () {
	var update = function() {
		var compoundData = createCpdTableData();
		var tableId = document.getElementById('cpdTable').value;
		initialize_table(tableId, compoundData);
	}

	execute_ajax('get_compound_table', 'cpd_tab', 'model='+modelIds.join(","), '', '', update);
}

// TABLE DATA - functions for loading data dynamically into Toby Tables

function createKeggMapData() {
	var ids = new Array();
	var data = new Array();
	var index = 0;
	for (var mapId in keggmaps) {
		ids[index] = mapId;
		var keggmap = keggmaps[mapId];
		var row = formatKeggMapRow(keggmap);
		data[index] = row;
		index++;
	}

	return {ids: ids, data: data};
}

function formatKeggMapRow (keggmap) {
	// loop through models to determine number of reactions and compounds
	var numReactions = new Array();
	var numCompounds = new Array();

	numReactions[0] = "0";
	numCompounds[0] = "0";

	var reactions = keggmap.REACTIONS;
	if (reactions) {
		numReactions[0] = reactions.length;
		for (var i=0; i<modelIds.length; i++) {
			var model = models[modelIds[i]];
			if (model != 0) {
				var numRxn = 0;
				for (var j=0; j<reactions.length; j++) {
					if (model.REACTIONS[reactions[j]]) numRxn++;
				}
				numReactions[i+1] = numRxn;
			}
		}
	}

	var compounds = keggmap.COMPOUNDS;
	if (compounds) {
		numCompounds[0] = compounds.length;
		for (var i=0; i<modelIds.length; i++) {
			var model = models[modelIds[i]];
			if (model != 0) {
				var numCpd = 0;
				for (var j=0; j<compounds.length; j++) {
					if (model.COMPOUNDS[compounds[j]]) numCpd++;
				}
				numCompounds[i+1] = numCpd;
			}
		}
	}

	var id = keggmap.ID;
	var name = keggmap.NAME;
	var openLink = '<a href="javascript:loadKeggMap(\'' + id + '\')">' + name + '</a>';

	var reactionCell = new Array();
	reactionCell[0] = "" + numReactions.shift();
	for (var i=0; i<numReactions.length; i++) {
		reactionCell[i+1] = "(<b style='color: " + colors[i] + ";'>" + numReactions[i] + "</b>)";
	}

	var compoundCell = new Array();
	compoundCell[0] = "" + numCompounds.shift();
	for (var i=0; i<numCompounds.length; i++) {
		compoundCell[i+1] = "(<b style='color: " + colors[i] + ";'>" + numCompounds[i] + "</b>)";
	}

	var numEcs = "" + 0;
	var ecs = keggmap.ECS;
	if (ecs) numEcs = "" + ecs.length;

	return [openLink, reactionCell.join("&nbsp;"), compoundCell.join("&nbsp;"), numEcs];
}

function createRxnTableData() {
	var data = new Array();
	var index = 0;
	for (var rxnId in reactions) {
		var rxn = reactions[rxnId];
		var row = formatReactionRow(rxn);
		data[index] = row;
		index++;
	}

	return data;
}

function formatReactionRow (reaction) {
	var reactionId = reactionLink(reaction.DATABASE);

	var name;
	if (reaction.NAME) {
		name = reaction.NAME.join("<br />");
	} else {
		name = 'None';
	}

/*
	var roles;
	if (reaction.ROLES) {
		roles = reaction.ROLES.join("<br />");
	} else {
		roles = 'none';
	}
	
	var subsystems;
	if (reaction.SUBSYSTEMS) {
		subsystems = reaction.SUBSYSTEMS.join("<br />");
	} else {
	 subsystems = 'none';
	}
*/
	
	var keggmaps;
	if (reaction.KEGG_MAPS) {
		keggmaps = keggMapLink(reaction.DATABASE);
	} else {
		keggmaps = 'None';
	}
	
	var enzymes;
	if (reaction.ENZYME) {
		enzymes = "";
		for (var i=0; i< reaction.ENZYME.length; i++) {
			if (i > 0) {
				enzymes += "<br />"; 
			}
			enzymes += enzymeLink(reaction.ENZYME[i]);
		}
	} else {
		enzymes = 'None';
	}
	
	var keggids;
	if (reaction.KEGGID) {
		keggids = "";
		for (var i=0; i< reaction.KEGGID.length; i++) {
			if (i > 0) {
				keggids += "<br />"; 
			}
			keggids += keggReactionLink(reaction.KEGGID[i]);
		}
	} else {
		keggids = 'None';
	}
	
	var row = [reactionId, name, reactionEquationLinks(reaction.EQUATION), keggmaps, enzymes, keggids];
/*
	for (var i=0; i<modelIds.length; i++) {
		var model = models[modelIds[i]];
		if (!model) continue;
		var modelReaction = model.REACTIONS[reactionId];
		if (modelReaction) {
			var mrString = '';
			var classes = modelReaction.CLASSES;
			if (classes) {
				for (var j=0; j<classes.length; j++) {
					mrString += classes[j].CLASS + "<br />";
					if (classes[j].MINFLUX) {
						mrString += classes[j].MINFLUX + " to " + classes[j].MAXFLUX + "<br />";
					}
				}
			
				mrString += "<br />";
			}			
			var pegs = modelReaction.PEGS;
			if (pegs) {
				for (var j=0; j<pegs.length; j++) {
					mrString += pegs[j] + "<br />";
				}
			}
			
			if (modelReaction.NOTE && modelReaction.NOTE != 'NONE') {
				mrString += "<br />Note: " + modelReaction.NOTE;
			}
			
			row.push(mrString);
		} else {
			row.push('Not in model');
		}
	}
	row.push(index);
*/
	return row;
}

function createCpdTableData() {
	var data = new Array();
	var index = 0;
	for (var cpdId in compounds) {
		var cpd = compounds[cpdId];
		var row = formatCompoundRow(cpd);
		data[index] = row;
		index++;
	}

	return data;
}

function formatCompoundRow (compound) {
	var compoundId = compoundLink(compound.DATABASE);

	var name;
	if (compound.NAME) {
		name = compound.NAME.join("<br />");
	} else {
		name = 'None';
	}

	var keggmaps;
	if (compound.KEGG_MAPS) {
		keggmaps = keggMapLink(compound.DATABASE);
	} else {
		keggmaps = 'None';
	}

	var keggids;
	if (compound.KEGGID) {
		keggids = "";
		for (var i=0; i< compound.KEGGID.length; i++) {
			if (i > 0) {
				keggids += "<br />"; 
			}
			keggids += keggCompoundLink(compound.KEGGID[i]);
		}
	} else {
		keggids = 'None';
	}

	var modelids;
	if (compound.MODELID) {
		modelids = compound.MODELID.join("<br />");
	} else {
		modelids = 'None';
	}
	
	var row = [compoundId, name, compound.FORMULA, compound.MASS, keggmaps, keggids, modelids];

	return row;
}

function createModelStatsTableData() {
	var data = new Array();
	var index = 0;
	for (var mdlID in models) {
		var mdl = models[mdlID];
		var row = formatModelStatsRow(mdl);
		data[index] = row;
		index++;
	}
	return data;
}

function formatModelStatsRow(modelObj) {
	var modelid = modelLink(modelObj.ID);
	var genome = genomeLink(modelObj.GENOME);
	var genes = modelObj.MDLGENECOUNT+"/"+modelObj.GENOMEGENECOUNT;
	var gaprxn = modelObj.RXNCOUNT - modelObj.RXNWITHGENES;
	var source = sourceLink(modelObj.SOURCE);
	var download = "";
	var modDate = "";
	var row = [modelid,modelObj.NAME,genome,modelObj.CLASS,genes,modelObj.RXNCOUNT,gaprxn,modelObj.CPDCOUNT,source,download,"V"+modelObj.VERSION,modDate];
	return row;
}

function createUserModelsTableData() {
	var data = new Array();
	var index = 0;
	for (var mdlID in models) {
		var mdl = models[mdlID];
		if (mdl.OWNER == "SELF") {
			var row = formatUserModelsRow(mdl);
			data[index] = row;
			index++;
		}
	}
	return data;
}

function formatUserModelsRow(modelObj) {
	var modelid = modelLink(modelObj.ID);
	var genome = genomeLink(modelObj.GENOME);
	var download = "";
	var modDate = "";
	var row = [modelid,modelObj.NAME,genome,modelObj.MESSAGE,download,modelObj.VERSION,modDate];
	return row;
}

// POST HOOK
// post_hook function for processing kegg map info
function processKeggMaps(keggmapTable) {
	var keggmapStrings = keggmapTable.split("\n");

	for (var i=0; i<keggmapStrings.length-1; i++) {
		var keggmap = new KeggMap(keggmapStrings[i]);
		keggmaps[keggmap.ID] = keggmap;
	}

	numkeggmaps = keggmapStrings.length - 2;

	createKeggMapTable();
}

// post_hook function for processing reaction info
function processReactions(reactionTable) {
	var reactionStrings = reactionTable.split("\n");

	for (var i=0; i<reactionStrings.length-1; i++) {
		var rxn = new Reaction(reactionStrings[i]);
		reactions[rxn.DATABASE] = rxn;
	}

	numreactions = reactionStrings.length - 2;

	createReactionTable();
}

// post_hook function for processing compound info
function processCompounds(compoundTable) {
	var compoundStrings = compoundTable.split("\n");

	for (var i=1; i<compoundStrings.length-1; i++) {
		var cpd = new Compound(compoundStrings[i]);
		compounds[cpd.DATABASE] = cpd;
	}

	numcompounds = compoundStrings.length - 2;

	createCompoundTable();
}

//post_hook function for processing model stats
function processModels(modelStrings) {
	for (var i=0; i<modelStrings.length; i++) {
		var mdl = new Model(modelStrings[i]);
		models[mdl.ID] = mdl;
	}
	nummodels = modelStrings.length;
	createModelStatsTable();
	createUserModelsTable();
}

//post_hook function for processing model reactions
function selectModelResponse (modelInfo) {
	var model = models[modelInfo.id];
	if (model) {
		model.REACTIONS = new Array();
		model.COMPOUNDS = new Array();
		for (var i=0; i < modelInfo.reactions.length; i++) {
			var newModelRxn =  new ModelReaction(modelInfo.reactions[i]);
			model.REACTIONS[newModelRxn.REACTION] = newModelRxn;
		}
		for (var i=0; i < modelInfo.compounds.length; i++) {
			var newModelCpd =  new ModelCompound(modelInfo.compounds[i]);
			model.COMPOUNDS[newModelCpd.COMPOUND] = newModelCpd;
		}
	}
}

// post_hook function for processing reaction link info
// like subsystems and roles
function processReactionLinkInfo(rxnInfoStrings) {

	for (var i=0; i<rxnInfoStrings.length-1; i++) {
		var rxnInfo = rxnInfoStrings[i].split(";");

		var rxnId = rxnInfo[0];

		var reaction = reactions[rxnId];

		if (rxnInfo[1] != "") {
			var roles = rxnInfo[1].split("|");
			reaction.ROLES = roles;
		}

		if (rxnInfo[2] != "") {
			var modelRoleInfo = rxnInfo[2].split("|");
			var modelRoles = new Array();
			for (var j=0; j<modelRoleInfo.length; j++) {
				var modelRole = new ModelRole(modelRoleInfo[j]);
				modelRoles[j] = modelRole;
			}    
			reaction.MODEL_ROLES = modelRoles;
		}

		if (rxnInfo[3] != "") {
			var subsystems = rxnInfo[3].split("|");
			reaction.SUBSYSTEMS = subsystems;
		}
	}
}

function addReactionLinkColumns() {
	var rxnTable = MVTables['rxnTable'];

	var roleColumn = new Array();
	var subsystemColumn = new Array();
	for (var rxnId in rxnTable.rows) {
		var reaction = reactions[rxnId];
		if (reaction) {
			var index = rxnTable.rows[rxnId];
	
			if (reaction.ROLES) {
				roleColumn[index] =reaction.ROLES.join("<br />");
			} else {
				roleColumn[index] ='none';
			}
		
			if (reaction.SUBSYSTEMS) {
				subsystemColumn[index] = reaction.SUBSYSTEMS.join("<br />");
			} else {
				subsystemColumn[index] = 'none';
			}
		}
	}

	var columns = ["Roles", "Subsystems"];
	var data = [roleColumn, subsystemColumn];
	rxnTable.addColumns(columns, data, 3);
}

function fillDiv(data) {
	var div = document.getElementById(data.div);
	if (div) {
		div.innerHTML = data.content;
	}
}

// TIMING
// Timing function: pass a function and name and an alert will be displayed telling the time to execute
function timeThis(func, name) {
	var Date1 = new Date();
	func();
	var Date2 = new Date();
	alert(name + ' took ' + (Date2.getTime() - Date1.getTime()) + ' milliseconds.');
}


// STORAGE
// Storage objects used throughout the ModelView web application
function KeggMap (keggmapString) {
	var keggmapArray = keggmapString.split(";");
	this.ID = keggmapArray[0];
	this.NAME = keggmapArray[1];

	var reactions = keggmapArray[2];
	if (reactions != '') this.REACTIONS = reactions.split("|");

	var compounds = keggmapArray[3];
	if (compounds != '') this.COMPOUNDS = compounds.split("|");

	var ecnumbers = keggmapArray[4];
	if (ecnumbers != '') this.ECS = ecnumbers.split("|");
}

function Reaction (rxnString) {
	var rxnArray = rxnString.split(";");
	this.DATABASE = rxnArray[0];
	this.EQUATION = rxnArray[2];

	var rev = rxnArray[5];
	if (rev != '') this.REVERSIBILITY = rxnArray[5];

	var name = rxnArray[1];
	if (name != '') this.NAME = name.split("|");

	var enzyme = rxnArray[3];
	if (enzyme != '') this.ENZYME = enzyme.split("|");

	var keggmap = rxnArray[4];
	if (keggmap != '') this.KEGG_MAPS = keggmap.split("|");

	var keggid = rxnArray[6];
	if (keggid != '') this.KEGGID = keggid.split("|");
}

function Compound (cpdString) {
	var cpdArray = cpdString.split(";");
	this.DATABASE = cpdArray[0];
	this.FORMULA = cpdArray[2];
	this.MASS = cpdArray[3];

	var name = cpdArray[1];
	if (name != '') this.NAME = name.split("|");

	var keggid = cpdArray[4];
	if (keggid != '') this.KEGGID = keggid.split("|");

	var modelid = cpdArray[5];
	if (modelid != '') this.MODELID = modelid.split("|");

	var keggmaps = cpdArray[6];
	if (keggmaps != '') this.KEGG_MAPS = keggmaps.split("|");
}

function ModelRole (modelRoleString) {
	var modelRoleInfo = modelRoleString.split("$");
	this.ROLE = modelRoleInfo[0];
	this.MODELS = modelRoleInfo[1].split("~");
}

function Model (mdlString) {
	var mdlArray = mdlString.split(";");
	this.ID = mdlArray[0];
	this.OWNER = mdlArray[1];
	this.USERS = mdlArray[2];
	this.NAME = mdlArray[3];
	this.SIZE = mdlArray[4];
	this.GENOME = mdlArray[5];
	this.SOURCE = mdlArray[6];
	this.MODDATE = mdlArray[7];
	this.BUILDDATE = mdlArray[8];
	this.ACDATE = mdlArray[9];
	this.STATUS = mdlArray[10];
	this.VERSION = mdlArray[11];
	this.MESSAGE = mdlArray[12];
	this.CLASS = mdlArray[13];
	this.MDLGENECOUNT = mdlArray[14];
	this.GENOMEGENECOUNT = mdlArray[15];
	this.RXNCOUNT = mdlArray[16];
	this.CPDCOUNT = mdlArray[17];
	this.RXNWITHGENES = mdlArray[16]-mdlArray[18];
	this.ACTIME = mdlArray[19];
	this.ACMEDIA = mdlArray[20];
	this.BIOMASS = mdlArray[21];
	this.GROWTH = mdlArray[22];
	this.NOGROWTHCPD = mdlArray[23];
	this.REACTIONS = new Array();
	this.COMPOUNDS = new Array();
}

function ModelReaction (modelRxnString) {
	var reactionInfo = modelRxnString.split(";");
	this.REACTION = reactionInfo[0];
	var classInfoString = reactionInfo[1];
	if (classInfoString != '') {
		var classInfoStrings = classInfoString.split("|");
		var classes = new Array();
		for (var i=0; i<classInfoStrings.length; i++) {
			var class = new ReactionClass(classInfoStrings[i]);
			classes[i] = class;
		}
		this.CLASSES = classes;
	}

	var pegString = reactionInfo[2];
	if (pegString != '') this.PEGS = pegString.split("|");

	var note = reactionInfo[3];
	this.NOTE = note;
}

function ReactionClass (reactionClassString) {
	var classInfo = reactionClassString.split("~");
	this.CLASS = classInfo[0];
	if (classInfo[1]) {
		this.MINFLUX = classInfo[1];
		this.MAXFLUX = classInfo[2];
	}
}

function ModelCompound (modelCompoundString) {
	var compoundInfo = modelCompoundString.split(";");
	this.COMPOUND = compoundInfo[0];
	var biomassString = compoundInfo[1];
	if (biomassString != '') this.BIOMASS = biomassString.split("|");
	var transportString = compoundInfo[2];
	if (transportString != '') this.TRANSPORT = transportString.split("|");
}
