/* CatalystX::CRUD::YUI custom JavaScript */
 
YAHOO.namespace('crud');

/* use FireBug for debugging if it is available */
if (!YAHOO.crud.log) {
    if (typeof console != 'undefined' && YAHOO.crud.OK2LOG) {
        if (window.console && !console.debug) {
            // safari
            //alert("window.console is defined");
            YAHOO.crud.log = function() { window.console.log(arguments[0]) };
        }
        else if (console.debug) {
            YAHOO.crud.log = console.debug;
        }
        else {
            alert("no window.console or console.debug");
            YAHOO.crud.log = function() { }; // do nothing
        }
        YAHOO.crud.log("console logger ok");
    }
    else {
        YAHOO.crud.log = function() { YAHOO.log(arguments); }
        YAHOO.crud.log("crud logger aliased to YAHOO.log");
    }
}


YAHOO.crud.handleXHRFailure = function(o) {
    alert("error: server failure (status = " + o.status + ")" + ' msg: ' + o.responseText);
};

/*
http://developer.yahoo.com/yui/examples/autocomplete/ac_ysearch_json.html
*/
YAHOO.crud.autocomplete_text_field = function( opts ) {

    this.oACDS = new YAHOO.widget.DS_XHR(opts.url, [ 'ResultSet.Result', opts.param.c, 'pk' ]);
    this.oACDS.queryMatchContains = true;
    this.oACDS.scriptQueryAppend  = opts.params;
    this.oACDS.maxCacheEntries    = opts.cache_size;
    
    var myItemSelectEventHandler = function( oSelf, elItem, oData ) {
        //YAHOO.crud.log('set ' + opts.fname + ' = ' + elItem[2][1]);
        var hiddenField = YAHOO.util.Dom.get(opts.fname);
        hiddenField.value = elItem[2][1];
    };

    // Instantiate AutoComplete
    this.oAutoComp = new YAHOO.widget.AutoComplete(opts.id, opts.container_id, this.oACDS);
    this.oAutoComp.useShadow = true;
    this.oAutoComp.maxResultsDisplayed = opts.limit;
    this.oAutoComp.itemSelectEvent.subscribe(myItemSelectEventHandler);
    
    /*
    this.oAutoComp.formatResult = function(oResultItem, sQuery) {
        return oResultItem[1].Title + " (" + oResultItem[1].Url + ")";
    };
    */
    /*
    this.oAutoComp.doBeforeExpandContainer = function(oTextbox, oContainer, sQuery, aResults) {
        var pos = YAHOO.util.Dom.getXY(oTextbox);
        pos[1] += YAHOO.util.Dom.get(oTextbox).offsetHeight + 2;
        YAHOO.util.Dom.setXY(oContainer,pos);
        return true;
    };
    */

    // Stub for form validation
    this.validateForm = function() {
        if (opts.validator) {
            return opts.validator();
        }
        else {
            return true;
        }
    };
};

YAHOO.crud.add_matrix_row = function( matrix ) {
            
    // populate the panel div with a datatable.

    // header
    YAHOO.crud.addRowMatrix.setHeader( 'Browse all ' + matrix.opts.name + ' records' );
    
    // body
    YAHOO.crud.addRowMatrix.setBody(
    '<div class="panel pager_wrapper">' + 
     '<div id="panel_msg"><span style="color:#fff;">placeholder</span></div>' + 
     '<div id="panel' + matrix.opts.pagerId + '" class="pager"></div>' + 
     '<div id="panel_autocomplete">' + 
      '<label for="panel_ac">Filter results:</label>' +
      '<input type="text" value="" id="panel_ac" class="autocomplete" />' + 
      '<div id="panel_ac_hidden" class="hidden"></div>' +
     '</div>' +
     '<br/>' +
    '</div>' +
    '<div id="relatedList"></div>'
    );
   
    // get initial stats 
    var handleSuccess = function(o) {
        if (o.responseText !== undefined) {
            //YAHOO.log("success text: " + o.responseText, "related");                  
            var stats = o.responseText.parseJSON();
            //alert("stats: " + stats.toJSONString());
            matrix.opts.pageSize         = parseInt(stats.pageSize, 10);
            matrix.opts.totalResults     = parseInt(stats.count, 10);
            matrix.opts.totalPages       = parseInt(stats.totalPages, 10);
            matrix.opts.currentPage      = parseInt(stats.page, 10);
            //alert("matrix stats set");
            
            // set the onclick handler for this particular matrix
            // when a row in the datatable is clicked, the related record is added
            // to the matrix and a XHR call is made back to the server to add it to the db.
            matrix.opts.rowClickHandler = function(oArgs) {
                YAHOO.util.Event.stopEvent(oArgs.event);
                var oSelf       = listMatrix;
                var oDataTable  = oSelf.myDataTable;
                var target      = oArgs.target;
                var record      = oDataTable.getRecord(target);
                var pks         = matrix.opts.pk;
                var pk_vals     = [];
                var i;
                for(i=0; i<pks.length; i++) {
                    pk_vals.push( encodeURIComponent( record.getData(pks[i]) ) );
                }
                var pk = pk_vals.join(';;');
       
                //alert(matrix.opts.name + ": got pk " + pk + ' cmap: ' + matrix.opts.cmap.toJSONString());
                if (matrix.opts.cmap) {
                    // just need to update the foreign key value in selected row
                    var postData = matrix.opts.cmap[1] + "=" + matrix.opts.parent_oid;
                    var url = matrix.opts.info_url + '/' + pk + '/save?return=json';
                    //alert("POST url: " + url + '?' + postData);
                    
                    var req = YAHOO.util.Connect.asyncRequest('POST', url,
                        {
                            success: function(o) {
                                if (o.responseText !== undefined) {
                                    var newRow = o.responseText.parseJSON();
                                    matrix.myDataTable.addRow(newRow, 0);
                                    YAHOO.util.Dom.get('panel_msg').innerHTML = 'Record added';
                                }
                                else {
                                    alert("unknown server error");
                                }
                            },
                            failure: function(o) {
                                YAHOO.crud.handleXHRFailure(o);
                                YAHOO.util.Dom.get('panel_msg').innerHTML = 
                                    '<span class="error">Action failed</span>';
                            }
                        },
                        postData);
                    
                }
                else {
                    var url = matrix.opts.parent_url + '/' + matrix.opts.parent + '/' + pk + '/add';
                    //alert("add_m2m :" + url);
                    
                    var req = YAHOO.util.Connect.asyncRequest('POST', url,
                        {
                            success: function(o) {
                                if (o.responseText !== undefined) {
                                    var newRow = o.responseText.parseJSON();
                                    newRow._remove = 'X';
                                    matrix.myDataTable.addRow(newRow, 0);
                                    YAHOO.util.Dom.get('panel_msg').innerHTML = 'Record added';
                                    YAHOO.crud.decorateRemoveCells();
                                }
                                else {
                                    alert("unknown server error");
                                }
                            },
                            failure: function(o) {
                                YAHOO.crud.handleXHRFailure(o);
                                YAHOO.util.Dom.get('panel_msg').innerHTML = 
                                    '<span class="error">Action failed</span>';
                            }
                        },
                        postData);  
                }
    
            }
            
            // create matrix object
            var listMatrix = YAHOO.crud.panelled_related_records_matrix(matrix.opts);
            
            // when panel is closed
            YAHOO.crud.addRowMatrix.hideEvent.subscribe(function() {
                // nothing for now
            });
    
            // show the populated panel
            YAHOO.crud.addRowMatrix.show();

        }
        else {
            alert("error: no data in server response");
        }
    };
        
    var callback = { 
        success: handleSuccess, 
        failure: YAHOO.crud.handleXHRFailure
    };
    var request = YAHOO.util.Connect.asyncRequest('GET', matrix.opts.count_url, callback);
    
}


/* 2.5.0 related records matrix. No History for this popup panel, but 
   does have sorting and autocomplete.
 */
YAHOO.crud.panelled_related_records_matrix = function( matrixOpts ) {
  
  YAHOO.crud.panel_state = {
    results:    matrixOpts.pageSize,
    startIndex: 0,
    sort:       matrixOpts.sortBy,
    dir:        "asc",
    filter:     ""
  };
  
  var MyMatrix = new function() {
    
    YAHOO.log("MyMatrix called", "matrix");
    YAHOO.log("opts = " + matrixOpts.toJSONString(), "matrix");

    var DataSource = YAHOO.util.DataSource,
        DataTable  = YAHOO.widget.DataTable,
        Paginator  = YAHOO.widget.Paginator,
        Dom        = YAHOO.util.Dom,
        Event      = YAHOO.util.Event;

    var mySource = new DataSource(matrixOpts.panel_url);
    mySource.responseType   = DataSource.TYPE_JSON;
    mySource.responseSchema = {
        resultsList : 'records',
        totalRecords: 'totalRecords',
        fields      : matrixOpts.fields
    };
    var myDataTable = null;
    
    if (Dom.get('panel_ac') && matrixOpts.colFilter) {
        Dom.get('panel_ac').value='';  // always reset to avoid sticky browsers
        var getFilter = function(query) {
            var req = '';
            // OR together all the filterable fields
            if (query.length) {
                var i;
                for(i=0; i<matrixOpts.colFilter.length; i++) {
                    req += '&' + matrixOpts.colFilter[i] + '=' + query;
                }
                req += '&_op=OR&_fuzzy=1';
            }
            // remember this query in state, from which buildQueryString() will work.
            YAHOO.crud.panel_state.filter = req;
            YAHOO.crud.panel_state.startIndex = 0;
            
            // Create callback for data request
            var oCallback = {
                success: myDataTable.onDataReturnInitializeTable,
                failure: myDataTable.onDataReturnInitializeTable,
                scope: myDataTable,
                argument: {
                    // Pass in sort values so UI can be updated in callback function
                    sorting: {
                        key: YAHOO.crud.panel_state.sort,
                        dir: YAHOO.crud.panel_state.dir
                    },
                    pagination: {
                        recordOffset: YAHOO.crud.panel_state.startIndex
                    }
                }
            }
            
            mySource.sendRequest(buildQueryString(0), oCallback);
        };
        
        // allow for empty query to return all records
        var checkFilterKey = function(acself, keycode) {
            if (!Dom.get('panel_ac').value.length) {
                getFilter('');
            }
        };
        
        var ACF = new YAHOO.widget.DS_JSFunction(getFilter);
        ACF.minQueryLength = 0;
        ACF.maxCacheEntries = 0; // always send request
        var ACFilter = new YAHOO.widget.AutoComplete("panel_ac", "panel_ac_hidden", ACF);
        ACFilter.textboxKeyEvent.subscribe(checkFilterKey);
    }
    else {
        Dom.get('panel_autocomplete').addClass('hidden');
    }

    var buildQueryString = function (state, datatable) {
        var offset = YAHOO.crud.panel_state.startIndex;
        var page_size = YAHOO.crud.panel_state.results;
        if (state) {
            offset = state.pagination.recordOffset;
            page_size = state.pagination.rowsPerPage;
        }
        return YAHOO.crud.generateStateString(
            offset,
            YAHOO.crud.panel_state.sort,
            YAHOO.crud.panel_state.dir,
            page_size
            ) + YAHOO.crud.panel_state.filter;
    };
    
    var handlePagination = function(state, datatable) {
    
        YAHOO.crud.log(state);
        
        YAHOO.crud.panel_state.startIndex = state.recordOffset;
        YAHOO.crud.panel_state.results    = state.rowsPerPage;
        return DataTable.handleDataSourcePagination(state, datatable);
    }
        
    // function used to intercept sorting requests
    var handleSorting = function (oColumn) {

        // Which direction
        var sDir = "asc";
        
        // Already sorted?
        if(oColumn.key === this.get("sortedBy").key) {
            sDir = (this.get("sortedBy").dir === "asc") ?
                    "desc" : "asc";
        }
        
        // must always return to page 1 because we can't rely on how sorted results are paged.
        YAHOO.crud.panel_state.startIndex = 0;
        YAHOO.crud.panel_state.dir = sDir;
        YAHOO.crud.panel_state.sort = oColumn.key;
        
        var req = buildQueryString(0);
        
        // Create callback for data request
        var oCallback = {
            success: this.onDataReturnInitializeTable,
            failure: this.onDataReturnInitializeTable,
            scope: this,
            argument: {
                // Pass in sort values so UI can be updated in callback function
                sorting: {
                    key: oColumn.key,
                    dir: (sDir === "asc") ? "asc" : "desc"
                },
                pagination: {
                    recordOffset: YAHOO.crud.panel_state.startIndex
                }
            }
        }
                
        // Send the request
        this.getDataSource().sendRequest(req, oCallback);
        
    };
    
    var myPaginator = new Paginator({
        containers         : ['panel' + matrixOpts.pagerId],
        pageLinks          : 5,
        rowsPerPage        : matrixOpts.pageSize,
        rowsPerPageOptions : [ { value: parseInt(matrixOpts.pageSize), text: matrixOpts.pageSize + '' }, { value: 50, text: '50' }, { value: 1000, text: '1000' }],
        firstPageLinkLabel  : '|&#171;',
        lastPageLinkLabel   : '&#187;|',
        previousPageLinkLabel: '&#171;',
        nextPageLinkLabel   : '&#187;',
        alwaysVisible       : true,  // in case user changes rowsPerPage
        template            : 
            "{CurrentPageReport} {FirstPageLink} {PreviousPageLink} {PageLinks} {NextPageLink} {LastPageLink} Page size: {RowsPerPageDropdown} <div class='pg-bar'></div>"
    });

    var myTableConfig = {
        initialRequest          : buildQueryString(),
        generateRequest         : buildQueryString,
        paginationEventHandler  : handlePagination,
        paginator               : myPaginator,
        width                   : matrixOpts.panel_width,
        height                  : matrixOpts.panel_height,
        scrollable              : true,
        sortedBy:               { key: matrixOpts.sortBy, dir: "asc" }
    };

    myDataTable = new DataTable(
        'relatedList',  // hardcoded DOM id , 
        matrixOpts.colDefs, 
        mySource, 
        myTableConfig
    );
    
    myDataTable.sortColumn = handleSorting;
    
    // Subscribe to events for row selection
    myDataTable.subscribe("rowMouseoverEvent", myDataTable.onEventHighlightRow);
    myDataTable.subscribe("rowMouseoutEvent",  myDataTable.onEventUnhighlightRow);
    myDataTable.subscribe("rowClickEvent",     matrixOpts.rowClickHandler);
    
    this.myDataTable = myDataTable;

  };
  
  return MyMatrix;
  
};

/*
=head2 related_records_matrix( opts )

Creates and renders Datatable object for records related to an object. Called from
the show_relationships.tt template for 'has_related()' objects.

=cut
*/
YAHOO.crud.related_records_matrix = function( opts ) {

    // create new arrays so we can optionally add remove button
    // and not affect original object.
    var myColumnDefs = [];
    var myFields     = [];
    var i;
    for (i=0; i < opts.colDefs.length; i++) {
        myColumnDefs[i] = opts.colDefs[i];
    }
    for (i=0; i < opts.fields.length; i++) {
        myFields[i] = opts.fields[i];
    }
    
    if (opts.add_remove_button) {
        myColumnDefs.push(
            {
                key:"_remove", 
                label:"", 
                title:"click to remove", // TODO doesn't work
                sortable:false
             }); 
        myFields.push("_remove");
    }

    // create handler for rowclick. delete a M2M or goto related record.
    var rowClickHandler;
    if ( opts.m2m ) {
      rowClickHandler = function(oArgs) {
        // get pk value for this row
        // 'this' is DataTable object
        YAHOO.util.Event.stopEvent(oArgs.event);
        var target      = oArgs.target;
        var vtarget     = YAHOO.util.Event.getTarget(oArgs.event);
        var record      = this.getRecord(target);
        var column      = this.getColumn(vtarget);
        var pks         = opts.pk;
        var pk_vals     = [];
        var i;
        for(i=0; i<pks.length; i++) {
            pk_vals.push( encodeURIComponent( record.getData(pks[i]) ) );
        }
        var pk = pk_vals.join(';;');
        var oDataTable  = this;
        
        // remove this row from relationship
        if (column.key == '_remove') {
            if (confirm('Are you sure?')) {
                // make ajax call to remove relationship
                YAHOO.util.Connect.asyncRequest(
                'POST',
                opts.rm_m2m_url + pk + '/remove',
                {
                    success: function (o) {
                        if (o.responseText == 'Ok') {
                        
                        // we must catch the err here because of a bug in the paginator
                        // that throws exception when there are no rows left in the table.
                        // e.g., we start with 3 rows and then delete them all. on the last
                        // delete, when deleteRow() is called the paginator croaks with
                        // an error about .getPageRecords() failing. That method is called
                        // via a rowUpdate event listener.
                            try {
                                oDataTable.deleteRow(target);  // visibly remove  
                            }
                            catch(err) {
                                /*
                                if (console) {
                                    console.debug(err);
                                }
                                */
                            }
                            oDataTable.render();  // sometimes DOM does not update otherwise
                            YAHOO.crud.decorateRemoveCells();
                            
                        } else {
                            alert(o.responseText);
                        }
                    },
                    failure: function (o) {
                        YAHOO.crud.handleXHRFailure(o);
                    }
                }
                );
            }
        }
        else if (opts.no_follow) {
            // do nothing
        
        }
        // redirect to detail screen
        else {
            var newurl      = opts.info_url + '/' + pk + '/' + opts.row_url_method;
            window.location.href = newurl;
        }
      };
    }
    else if (opts.no_follow) {
    
      rowClickHandler = function(oArgs) {
        // do nothing.
      };
    
    }
    else {
      rowClickHandler = function(oArgs) {
        // get pk value for this row
        // 'this' is DataTable object
        //alert("caught row click for this " + this);
        YAHOO.util.Event.stopEvent(oArgs.event);
        var target      = oArgs.target;
        var vtarget     = YAHOO.util.Event.getTarget(oArgs.event);
        var record      = this.getRecord(target);
        var column      = this.getColumn(vtarget);
        var pks         = opts.pk;
        var pk_vals     = [];
        var i;
        for(i=0; i<pks.length; i++) {
            pk_vals.push( encodeURIComponent( record.getData(pks[i]) ) );
        }
        var pk = pk_vals.join(';;');
        var newurl      = opts.info_url + '/' + pk + '/' + opts.row_url_method;
        window.location.href = newurl;   
      };
    }
    
    var Matrix = YAHOO.crud.create_results_matrix(
    {
        colDefs:    myColumnDefs,
        fields:     myFields,
        url:        opts.url,  
        anchor:     opts.anchor,
        pageSize:   opts.pageSize,
        pagerId:    opts.pagerId,
        pk:         opts.pk,
        sortBy:     opts.sortBy,
        totalPages: opts.totalPages,
        totalResults: opts.totalResults,
        divId:      opts.divId,
        rowClickHandler: rowClickHandler
    }
    );

    YAHOO.crud.decorateRemoveCells();    
    Matrix.opts = opts;

    return Matrix;
}

YAHOO.crud.decorateRemoveCells = function() {
    // add helpful title to all _remove divs
    // and 'hover' class for css
    var removeCells = YAHOO.util.Dom.getElementsByClassName('yui-dt-col-_remove');
    var i;
    for(i=0; i<removeCells.length; i++) {
        removeCells[i].setAttribute('title', 'click to remove associated record');
        YAHOO.util.Event.addListener(removeCells[i], 'mouseover', function(ev) {
            if(!YAHOO.util.Dom.addClass(YAHOO.util.Event.getTarget(ev), 'hover')) {
                //alert("failed to add hover");
            }
        });
        YAHOO.util.Event.addListener(removeCells[i], 'mouseout', function(ev) {
            if(!YAHOO.util.Dom.removeClass(YAHOO.util.Event.getTarget(ev), 'hover')) {
                //alert("failed to remove hover");
            }
        });
    }
}

// method to generate a query string for the DataSource.  
// Also used as the state indicator for the History Manager
YAHOO.crud.generateStateString = function (start,key,dir,psize) {
    return  "&_page_size="  +   psize   + 
            "&_offset="     +   start   +
            "&_sort="       +   key     +
            "&_dir="        +   dir;
};

// method to extract the key values from the state string
YAHOO.crud.parseStateString = function (state) {
    return {
        results    : /\b_page_size=(\d+)/.test(state)   ? parseInt(RegExp.$1) : 20,
        startIndex : /\b_offset=(\d+)/.test(state)      ? parseInt(RegExp.$1) : 0,
        sort       : /\b_sort=(\w+)/.test(state)        ? RegExp.$1 : 'id',
        dir        : /\b_dir=([\w\-]+)/.test(state)     ? RegExp.$1 : 'asc'
    }
};

YAHOO.crud.handleHistoryNavigation = function (state, myMatrix) {
    // Create a payload to pass through the DataSource request to the
    // handler
    
    YAHOO.crud.log("historyNavigation state");
    YAHOO.crud.log(state);
    YAHOO.crud.log(myMatrix);
    
    var parsed = YAHOO.crud.parseStateString(state);
    var oPayload = {
        startIndex : parsed.startIndex,
        pagination : {
            recordOffset : parsed.startIndex,
            rowsPerPage  : parsed.results
        },
        sorting : {
            key : parsed.sort,
            dir : parsed.dir
        }
    };

    // Use the DataTable's baked in server-side pagination handler
    myMatrix.myDataSource.sendRequest(state,{
            success  : myMatrix.myDataTable.onDataReturnSetRecords,
            failure  : myMatrix.myDataTable.onDataReturnSetRecords,
            scope    : myMatrix.myDataTable,
            argument : oPayload
    });
    
    YAHOO.crud.log("navigation done");
};

/* 2.5.0 matrix 
   taken nearly verbatim from:
   http://developer.yahoo.com/yui/examples/datatable/dt_server_pag_sort_clean.html
 */
YAHOO.crud.create_results_matrix = function( matrixOpts ) {

    YAHOO.crud.matrix_state = {
        results:    matrixOpts.pageSize,
        startIndex: 0,
        sort:       matrixOpts.sortBy,
        dir:        "asc"
    };
  
    if (!YAHOO.crud.historyList) {
        YAHOO.crud.historyList = [];
    }
  
    var myMatrix = {};
    
    var History = YAHOO.util.History;
        
    var myDataSource,
        myDataTable,
        myPaginator;
    
    YAHOO.crud.log("MyMatrix called");
    YAHOO.crud.log(matrixOpts);
        
    // function used to intercept pagination requests
    var handlePagination = function (state,datatable) {
    
        YAHOO.crud.log(state);
    
        var sortedBy  = datatable.get('sortedBy');

        var newState = YAHOO.crud.generateStateString(
                            state.recordOffset,
                            sortedBy.key,
                            sortedBy.dir,
                            state.rowsPerPage
                        );
        
        YAHOO.crud.matrix_state = YAHOO.crud.parseStateString(newState);

        History.navigate(matrixOpts.anchor,newState);

    }; 

    // function used to intercept sorting requests
    var handleSorting = function (oColumn) {
        // Which direction
        var sDir = "asc";

        // Already sorted?
        if(oColumn.key === this.get("sortedBy").key) {
            sDir = (this.get("sortedBy").dir === "asc") ?
                    "desc" : "asc";
        }

        var newState = YAHOO.crud.generateStateString(
                            0, oColumn.key, sDir, matrixOpts.pageSize);
                            
        YAHOO.crud.matrix_state = YAHOO.crud.parseStateString(newState);

        History.navigate(matrixOpts.anchor, newState);
    };


    var doBeforeLoadData = function (oRequest, oResponse, oPayload) {
        oPayload = oPayload || {};
        if (!YAHOO.lang.isNumber(oPayload.startIndex)) {
            oPayload.startIndex = this.get('paginator').getStartIndex();
        }

        return true;
    };

    var initialState = History.getBookmarkedState(matrixOpts.anchor) 
                        || YAHOO.crud.generateStateString(0,matrixOpts.sortBy,'asc',matrixOpts.pageSize);
        
    History.register(matrixOpts.anchor, initialState, YAHOO.crud.handleHistoryNavigation, myMatrix);

    YAHOO.crud.historyList.push(
      function() {
      
        YAHOO.crud.log("onReady for History " + matrixOpts.anchor);
        
        // Pull the state from the History Manager, or default from the
        // initial state.  Parse the state string into an object literal.
        var initialRequest = History.getCurrentState(matrixOpts.anchor) ||
                             matrixOpts.initialState || initialState,
            state          = YAHOO.crud.parseStateString(initialRequest);

        // Create the DataSource
        myDataSource = new YAHOO.util.DataSource(matrixOpts.url);
        myDataSource.responseType = YAHOO.util.DataSource.TYPE_JSON;
        myDataSource.responseSchema = {
            resultsList:    "records",
            totalRecords:   "totalRecords",
            fields:         matrixOpts.fields
        };
        
        YAHOO.crud.log("this = ", this);
        
        // Column definitions
        var myColumnDefs = matrixOpts.colDefs;

        // Create the DataTable configuration and Paginator using the state
        // information we pulled from the History Manager
        myPaginator = new YAHOO.widget.Paginator({
            rowsPerPage             : state.results,
            rowsPerPageOptions      : [ { value: parseInt(matrixOpts.pageSize), text: matrixOpts.pageSize }, { value: 50, text: '50' }, { value: 1000, text: '1000' }],
            totalRecords            : matrixOpts.totalResults,
            pageLinks               : 5,
            recordOffset            : state.startIndex,
            containers              : [matrixOpts.pagerId],
            firstPageLinkLabel      : '|&#171;',
            lastPageLinkLabel       : '&#187;|',
            previousPageLinkLabel   : '&#171;',
            nextPageLinkLabel       : '&#187;',
            alwaysVisible           : true,  // in case user changes rowsPerPage
            template                : 
                "{CurrentPageReport} {FirstPageLink} {PreviousPageLink} {PageLinks} {NextPageLink} {LastPageLink} Page size: {RowsPerPageDropdown} <div class='pg-bar'></div>"
        });

        var myConfig = {
            paginator : myPaginator,
            paginationEventHandler : handlePagination,
            sortedBy : {
                key : state.sort,
                dir : state.dir
            },
            initialRequest : initialRequest
        };

        // Instantiate DataTable
        myDataTable = new YAHOO.widget.DataTable(
            matrixOpts.divId, // The dom element to contain the DataTable
            myColumnDefs,        // What columns will display
            myDataSource,   // The DataSource for our records
            myConfig             // The configuration for *this* instantiation
        );
        
        // remember these for callbacks
        myMatrix.myPaginator = myPaginator;
        myMatrix.myDataSource = myDataSource;
        myMatrix.myDataTable = myDataTable;

        // Listen to header link clicks to sort the column
        myDataTable.subscribe('theadCellClickEvent', myDataTable.onEventSortColumn);

        // Override the DataTable's sortColumn method with our intercept handler
        myDataTable.sortColumn = handleSorting;
        
        // Override the doBeforeLoadData method to make sure we initialize the
        // DataTable's RecordSet from the proper starting index
        myDataTable.doBeforeLoadData = doBeforeLoadData;
        
        // Enables single-mode row selection
        myDataTable.set("selectionMode","single");
        
        // make each row click-able with action defined by caller.
        // Subscribe to events for row selection
        if(!matrixOpts.no_follow) {
            myDataTable.subscribe("rowMouseoverEvent", myDataTable.onEventHighlightRow);
            myDataTable.subscribe("rowMouseoutEvent",  myDataTable.onEventUnhighlightRow);
        }
        myDataTable.subscribe("rowClickEvent",     matrixOpts.rowClickHandler);

        // Programmatically select the first row immediately
        //myDataTable.selectRow(myDataTable.getTrEl(0));
                
        // Programmatically bring focus to the instance so arrow selection works immediately
        //myDataTable.focus();
        
        // set event listeners on paginator page nums to create hover effect
        YAHOO.crud.hover_class_on_mousemove(matrixOpts.pagerId);

        // set up autocomplete filter
        var buildQueryString = function (state, datatable) {
            var offset = YAHOO.crud.matrix_state.startIndex;
            var page_size = YAHOO.crud.matrix_state.results;
            if (state) {
                offset      = state.pagination.recordOffset;
                page_size   = state.pagination.rowsPerPage;
            }
            return YAHOO.crud.generateStateString(
                offset,
                YAHOO.crud.matrix_state.sort,
                YAHOO.crud.matrix_state.dir,
                page_size
                );
        };
    
        if (matrixOpts.colFilter && YAHOO.util.Dom.get('results_ac')) {
            YAHOO.util.Dom.get('results_ac').value='';  // always reset to avoid sticky browsers
            var getFilter = function(query) {
                var req = buildQueryString(0);
                // OR together all the filterable fields
                if (query.length) {
                    var i;
                    for(i=0; i<matrixOpts.colFilter.length; i++) {
                        req += '&' + matrixOpts.colFilter[i] + '=' + query;
                    }
                    req += '&_op=OR&_fuzzy=1';
                }
                myDataSource.sendRequest(req, myDataTable.onDataReturnInitializeTable, myDataTable);
            };
            
            // allow for empty query to return all records
            var checkFilterKey = function(acself, keycode) {
                if (!YAHOO.util.Dom.get('results_ac').value.length) {
                    getFilter('');
                }
            };
            
            var ACF = new YAHOO.widget.DS_JSFunction(getFilter);
            ACF.minQueryLength = 0;
            ACF.maxCacheEntries = 0; // always send request
            var ACFilter = new YAHOO.widget.AutoComplete("results_ac", "results_ac_hidden", ACF);
            ACFilter.textboxKeyEvent.subscribe(checkFilterKey);
        }
        
      } // end function()
    
    );  // end .push
  
    return myMatrix;
  
};

YAHOO.crud.init_histories = function () {

    YAHOO.crud.log("HistoryList init " + YAHOO.crud.historyList.length);

    // set an onReady function that calls each function in our list
    YAHOO.util.History.onReady(function() {
    
        var i;
        for(i=0; i < YAHOO.crud.historyList.length; i++) {
            var func = YAHOO.crud.historyList[i];
            func();
        }
        
    });
    
    YAHOO.util.History.initialize("yui_history_field", "yui_history_iframe");
}

/* utils */
YAHOO.crud.cancel_action = function (ev) { return false }

YAHOO.crud.hover_class_on_mousemove = function(id) {
    YAHOO.util.Event.addListener(id, 'mouseover', function(ev) {
    
        var elTarget = YAHOO.util.Event.getTarget(ev);
        while(elTarget.id != id) {
            if (elTarget.nodeName.toUpperCase() != "A") {
                elTarget = elTarget.parentNode;
                break;
            }
            if (    YAHOO.util.Dom.hasClass(elTarget, 'yui-pg-page')
                ||  YAHOO.util.Dom.hasClass(elTarget, 'yui-pg-first')
                ||  YAHOO.util.Dom.hasClass(elTarget, 'yui-pg-previous')
                ||  YAHOO.util.Dom.hasClass(elTarget, 'yui-pg-next')
                ||  YAHOO.util.Dom.hasClass(elTarget, 'yui-pg-last')
            ) {
                YAHOO.util.Dom.addClass(elTarget, 'hover');
                break;
            }
            else {
                elTarget = elTarget.parentNode;
            }
        }
    
    });
    YAHOO.util.Event.addListener(id, 'mouseout', function(ev) {
    
        var elTarget = YAHOO.util.Event.getTarget(ev);
        while(elTarget.id != id) {
            if (elTarget.nodeName.toUpperCase() != "A") {
                elTarget = elTarget.parentNode;
                break;
            }
            if (YAHOO.util.Dom.hasClass(elTarget, 'hover')) {
                YAHOO.util.Dom.removeClass(elTarget, 'hover');
                break;
            }
            else {
                elTarget = elTarget.parentNode;
            }
        }
    
    });
}
         
YAHOO.crud.disable_button = function (button) {
    button.oldValue     = button.value;
    button.value        = '...in process...';

    if (typeof button.disabled != 'undefined')
        button.disabled = true;
    else if (!button.buttonDisabled)
    {
        button.oldOnclick       = button.onclick;
        button.onclick          = YAHOO.crud.cancel_action;
        button.buttonDisabled   = true;
    }
}

YAHOO.crud.enable_button = function (button) {
    button.value        = button.oldValue;
    if (typeof button.disabled != 'undefined')
        button.disabled = false;
    else if (button.buttonDisabled) {
        button.onclick          = button.oldOnclick;
        button.buttonDisabled   = false;
    }
}

YAHOO.crud.enable_all_buttons = function(id) {
    if (!id)
        id = 'addRowButton';
        
    var buttons = YAHOO.util.Dom.getElementsByClassName(id);
    for (var i = 0; i < buttons.length; i++) {
        YAHOO.crud.enable_button(buttons[i]);
    }
}

YAHOO.crud.disable_all_buttons = function(id) {
    if (!id)
        id = 'addRowButton';
        
    var buttons = YAHOO.util.Dom.getElementsByClassName(id);
    for (var i = 0; i < buttons.length; i++) {
        YAHOO.crud.disable_button(buttons[i]);
    }
}



/* draggable, resizeable panel via YUI. This is for adding rows to a related-row
   matrix datatable.
   See http://developer.yahoo.com/yui/examples/container/panel-resize.html
 */
 

// BEGIN RESIZEPANEL SUBCLASS //
YAHOO.widget.ResizePanel = function(el, userConfig) {
	if (arguments.length > 0) {
		YAHOO.widget.ResizePanel.superclass.constructor.call(this, el, userConfig);
	}
}

YAHOO.widget.ResizePanel.CSS_PANEL_RESIZE  = "yui-resizepanel";
YAHOO.widget.ResizePanel.CSS_RESIZE_HANDLE = "resizehandle";

YAHOO.extend(YAHOO.widget.ResizePanel, YAHOO.widget.Panel, {
    init: function(el, userConfig) {
        YAHOO.widget.ResizePanel.superclass.init.call(this, el);
        this.beforeInitEvent.fire(YAHOO.widget.ResizePanel);
        var Dom = YAHOO.util.Dom,
            Event = YAHOO.util.Event,
            oInnerElement = this.innerElement,
            oResizeHandle = document.createElement("DIV"),
            sResizeHandleId = this.id + "_resizehandle";

        oResizeHandle.id = sResizeHandleId;
        oResizeHandle.className = YAHOO.widget.ResizePanel.CSS_RESIZE_HANDLE;
        Dom.addClass(oInnerElement, YAHOO.widget.ResizePanel.CSS_PANEL_RESIZE);
        this.resizeHandle = oResizeHandle;
        
        function initResizeFunctionality() {
            var me = this,
                oHeader = this.header,
                oBody = this.body,
                oFooter = this.footer,
                nStartWidth,
                nStartHeight,
                aStartPos,
                nBodyBorderTopWidth,
                nBodyBorderBottomWidth,
                nBodyTopPadding,
                nBodyBottomPadding,
                nBodyOffset;
    
    
            oInnerElement.appendChild(oResizeHandle);
            this.ddResize = new YAHOO.util.DragDrop(sResizeHandleId, this.id);
            this.ddResize.setHandleElId(sResizeHandleId);
            this.ddResize.onMouseDown = function(e) {
    
                nStartWidth = oInnerElement.offsetWidth;
                nStartHeight = oInnerElement.offsetHeight;
    
                if (YAHOO.env.ua.ie && document.compatMode == "BackCompat") {
                    nBodyOffset = 0;
                }
                else {
                    nBodyBorderTopWidth = parseInt(Dom.getStyle(oBody, "borderTopWidth"), 10),
                    nBodyBorderBottomWidth = parseInt(Dom.getStyle(oBody, "borderBottomWidth"), 10),
                    nBodyTopPadding = parseInt(Dom.getStyle(oBody, "paddingTop"), 10),
                    nBodyBottomPadding = parseInt(Dom.getStyle(oBody, "paddingBottom"), 10),
                    nBodyOffset = nBodyBorderTopWidth + nBodyBorderBottomWidth + 
                                  nBodyTopPadding + nBodyBottomPadding;
                }
    
                me.cfg.setProperty("width", nStartWidth + "px");
                aStartPos = [Event.getPageX(e), Event.getPageY(e)];
            };
            
            this.ddResize.onDrag = function(e) {
    
                var aNewPos = [Event.getPageX(e), Event.getPageY(e)],
                    nOffsetX = aNewPos[0] - aStartPos[0],
                    nOffsetY = aNewPos[1] - aStartPos[1],
                    nNewWidth = Math.max(nStartWidth + nOffsetX, 10),
                    nNewHeight = Math.max(nStartHeight + nOffsetY, 10),
                    nBodyHeight = (nNewHeight - (oFooter.offsetHeight + 
                                                 oHeader.offsetHeight + nBodyOffset));
    
                me.cfg.setProperty("width", nNewWidth + "px");
    
                if (nBodyHeight < 0) {
                    nBodyHeight = 0;
                }
                oBody.style.height =  nBodyHeight + "px";
                
                // allow for additional callbacks
                if (me.myLayout) {
                    YAHOO.crud.log("resize layout");
                    me.myLayout.resize({ height: nNewHeight, width: nNewWidth });
                }
            };
        
        }
       
    
        function onBeforeShow() {
           initResizeFunctionality.call(this);
           this.unsubscribe("beforeShow", onBeforeShow);
        }
        
        function onBeforeRender() {            
            if (!this.footer) {
                this.setFooter("");
            }
    
            if (this.cfg.getProperty("visible")) {
                initResizeFunctionality.call(this);
            }
            else {
                this.subscribe("beforeShow", onBeforeShow);
            }
            
            this.unsubscribe("beforeRender", onBeforeRender);
        }
           
        this.subscribe("beforeRender", onBeforeRender);

        if (userConfig) {
            this.cfg.applyConfig(userConfig, true);
        }
    
        this.initEvent.fire(YAHOO.widget.ResizePanel);
    },
    
    toString: function() {
        return "ResizePanel " + this.id;
    }
});

YAHOO.crud.toggle_class_hidden = function(id) {
    var DOM     = YAHOO.util.Dom;
    var element = DOM.get(id);
    if (DOM.hasClass(element, "hidden")) {
        DOM.removeClass(element, "hidden");
    }
    else {
        DOM.addClass(element, "hidden");
    }
}

YAHOO.crud.toggle_link = function(id_to_toggle, link_id) {
    YAHOO.crud.toggle_class_hidden(id_to_toggle);
    YAHOO.crud.toggle_class_hidden(link_id);
    return false;   // so the click is not followed on a href
}
