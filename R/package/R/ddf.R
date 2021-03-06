#' A S4 class that represents a DistributedDataFrame
#' 
#' @param jddf Java object reference to the backing DistributedDataFrame
#' @exportClass DDF
#' @rdname DDF
setClass("DDF",
         representation(jddf="jobjRef"),
         prototype(jddf=NULL)
)

setMethod("initialize",
          signature(.Object="DDF"),
          function(.Object, jddf) {
            if (is.null(jddf) || !inherits(jddf, "jobjRef") || !(jddf %instanceof% "io.ddf.DDF"))
              stop('DDF needs a Java object of class "io.ddf.DDF"')
            .Object@jddf = jddf
            .Object
          })

setValidity("DDF",
            function(object) {
              jddf <- object@jddf
              cls <- jddf$getClass()
              className <- cls$getName()
              if (grep("io.*.ddf.*DDF", className) == 1) {
                TRUE
              } else {
                paste("Invalid DDF class ", className)
              }
            }
)

#' @rdname DDF
#' @export
DDF <- function(jddf) {
  new("DDF", jddf)
}

#' Retrieve a DistributedDataFrame's column names
#' 
#' @param x a DDF object
#' @return a character vector
#' @export
setMethod("colnames",
          signature("DDF"),
          function(x) {
            sapply(x@jddf$getColumnNames(), function(obj) {obj$toString()})
          }
)

#' @export
setGeneric("coltypes",
           function(x){
             standardGeneric("coltypes")
           })

setMethod("coltypes",
          signature("DDF"),
          function(x) {
  col.names <- colnames(ddf)
  sapply(col.names, function(cn) {ddf@jddf$getColumn(cn)$getType()$toString()})
})

#' Get a DistributedDataFrame's number of rows
#' 
#' @param x a DDF object
#' @return an integer of length 1 or NULL
#' @export
setMethod("nrow",
          signature("DDF"),
          function(x) {
            x@jddf$getNumRows()
          }
)

#' Get a DistributedDataFrame's number of columns
#' 
#' @param x a DDF object
#' @return an integer of length 1 or NULL
#' @export
setMethod("ncol",
          signature("DDF"),
          function(x) {
            x@jddf$getNumColumns()
          }
)

#' Return a statistical summary of a DistributedDataFrame's columns
#' 
#' @param object a DistributedDataFrame
#' @return a data.frame containing summary numbers
#' @export
setMethod("summary",
          signature("DDF"),
          function(object) {
            ret <- as.data.frame(sapply(object@jddf$getSummary(), 
                                        function(col) {
                                          if (!is.jnull(col)) {
                                            return(c(col$mean(), col$stdev(), col$count(), col$NACount(), col$min(), col$max()))
                                          } else {
                                            return(rep(NA, 6))
                                          }})
                                 )
            colnames(ret) <- colnames(object)
            rownames(ret) <- c("mean", "stdev", "count", "cNA", "min", "max")
            ret
          }
)

#' DistributedDataFrame subsetting/filtering for extracting values
#' 
#' @section Usage:
#' \describe{
#'  \code{x[i,j,...,drop=TRUE]}
#' }
#' @rdname open-brace
#' @param x the DistributedDataFramee.
#' @param i empty or an expression to filter rows.
#' @param j column names or indices.
#' @param drop coerce the DistributedDataFrame result to a DistributedVector if only one column is specified.
#' @return a DistributedDataFrame or a DistributedVector.
#' @name [-DDF
#' @export
setMethod("[", signature(x="DDF"),
          function(x, i,j,...,drop=TRUE) {
            .subset(x, i,j,...,drop)
          }  
)

.subset <- function(x, i,j,...,drop) {
  if (missing(j))
    col.names <- colnames(x)
  else
    col.names <- sapply(j, function(col) {
      if (is.numeric(col)) {
        # validate column index
        if (col < 0 || col > ncol(x) || !isInteger(col))
          stop(paste0("Invalid column indices - ",col), call.=F)
        return(colnames(x)[col])
      } else {
        # validate column name
        if (!(col %in% colnames(x)))
          stop(paste0("Invalid column name - ",col), call.=F)
        return(col)
      }
    })
  
  names(col.names) <- NULL
  
  new("DDF", x@jddf$VIEWS$project(.jarray(col.names)))
}


#' Return the First Part of a DistributedDataFrame
#' 
#' @details
#' \code{head} for a DistributedDataFrame returns the first rows of that DistributedDataFrame as an R native data.frame.
#' @param x a DistributedDataFrame
#' @param n a single positive integer, rows for the resulting \code{data.frame}.
#' @return an R native data.frame
#' @export
setMethod("head",
          signature("DDF"),
          function(x, n=6L) {
            res <- x@jddf$VIEWS$head(as.integer(n))
            if(ncol(x)>1)
                res <- t(sapply(res, function(x){x$split("\t")}))
            else
                res <- as.matrix(sapply(res, function(x){x$split("\t")}))
            get.data.frame(colnames(x), coltypes(x), res)
          }
)

#' Return all the of a DistributedDataFrame as a R datafrme
#'
#' @details
#' \code{as.data.frame} for a DistributedDataFrame returns all the data of that DistributedDataFrame as an R native data.frame.
#' @param x a DistributedDataFrame
#' @return an R native data.frame
#' @export
setMethod("as.data.frame",
          signature("DDF"),
          function(x) {
            head(x,nrow(x))
          }
)

#' Return a sample of specific size from a DistributedDataFrame
#' 
#' @param x a DistributedDataFrame
#' @param size number of samples
#' @param replace sampling with or without replacement
#' @param seed a random seed
#' @export
setMethod("sample",
          signature("DDF"),
          function(x, size, replace=FALSE, seed=123L) {
            res <- x@jddf$VIEWS$getRandomSample(as.integer(size), replace, seed)
            ncols <- ncol(x)
            parsed.res <- t(sapply(res, 
                          function(x) {sapply(1:ncols, function(y){.jarray(x)[[y]]$toString()})}))
            get.data.frame(colnames(ddf), coltypes(ddf), parsed.res)
          }
)

#' Sample a fraction of rows from a DistributedDataFrame
#' 
#' @param x a DistributedDataFrame
#' @param percent a double value specify the fraction
#' @param replace sampling with or without replacement
#' @param seed a random seed
#' @return a DistributedDataFrame
#' @export
setGeneric("sample2ddf",
           function(x, ...) {
             standardGeneric("sample2ddf")
           }
)

setMethod("sample2ddf",
          signature("DDF"),
          function(x, percent, replace=FALSE, seed=123L) {
            new ("DDF",x@jddf$VIEWS$getRandomSample(percent, replace, seed))
          }
)

#' Compute Summary Statistics of a Distributed Data Frame's Subsets
#' 
#' Splits a Distributed Data Frame into subsets, computes summary statistics for each, 
#' and returns the result in a convenient form.
#' @details \code{aggregate.formula} is a standard formula interface to \code{daggr}.
#' @param formula in format, \code{y ~ x1 + x2} or \code{cbind(y1,y2) ~ x1 + x2} where \code{x1, x2} are group-by variables and \code{y,y1,y2} are variables to aggregate on.
#' @param data a Distributed Data Frame
#' @param FUN the aggregate function, currently support mean, median, var, sum.
#' @return a data frame with columns corresponding to the grouping variables in by followed by aggregated columns from data.
#' @export
#' @rdname ddf-aggregate
aggregate.formula <- function(formula, data, FUN) {
  # parse formula's left hand side expression
  left.vars <- formula[[2]]
  if (length(left.vars) == 1)
    left.vars <- deparse(left.vars)
  else if (identical(deparse(left.vars[[1]]), "cbind")) {
    left.vars <- sapply(left.vars, deparse)[-1]
  } else stop("Unsupported operation on left hand side of the formula!!!")
  
  left.vars <- unique(left.vars)
  
  # parse formula's right hand side expression
  right.vars <- str_trim(unlist(strsplit(as.character(deparse(formula[[3]]))," \\+ ")))
  vars <- append(left.vars, right.vars)
  vars_idx <- .lookup(vars, colnames(data))
  if (is.character(vars_idx))
    stop(vars_idx)
  
  right.vars <- unique(right.vars)
  
  # variable in left-hand side must not be in righ-hand size
  errors <- NULL
  for(x in left.vars) {
    if (x %in% right.vars) {
      if (is.null(errors)) 
        errors <- paste0(x, " is in both side of formula") 
      else errors <- c(errors, paste0(x, " is in both side of formula"))}
  }
  
  if (!is.null(errors))
    stop(paste(errors, collapse="\n"))
  
  # check if FUN is a valid one
  fname <- deparse(substitute(FUN))
  if (is.na(pmatch(fname,c("sum", "count", "mean","median","variance"))))
    stop("Only support these FUNs: sum, count, mean, median, variance")
  if (identical(fname,"var"))
    fname <- "variance"
  
  
  res <- .aggregate(data, sapply(left.vars, function(var) {paste0(fname, "(", var, ")")}), right.vars)
  colnames(res) <- c(right.vars, sapply(left.vars, function(var) {paste0(fname, "(", var, ")")}))
  res
}

#' @param x a Distributed Data Frame
#' @param agg.cols a list of columns to calculate summary statistics
#' @param by a list of grouping columns
#' @method aggregate DDF
#' @export
#' @rdname ddf-aggregate
setMethod("aggregate",
          signature("DDF"),
          function(x, agg.cols, by) {
            .aggregate(x, str_trim(unlist(strsplit(agg.cols,","))), str_trim(unlist(strsplit(by,","))))
          }
)

.aggregate <- function(x, agg.cols, by) {
  cols_str <- paste(c(by, agg.cols), collapse=",")
  
  jres <- x@jddf$aggregate(cols_str)
  
  agg_vals <- sapply(jres$keySet(), function(k) {jres$get(k)})
  if (is.vector(agg_vals)) {
    agg_res <- as.data.frame(agg_vals)
  } else {
    agg_res <- as.data.frame(t(agg_vals))
  }
  
  group_vals <- sapply(jres$keySet(), function(x) {x$split("\t")})
  if (is.vector(group_vals)) {
    group_res <- as.data.frame(group_vals, stringsAsFactors=F)
  } else {
    group_res <- as.data.frame(t(group_vals), stringsAsFactors=F)
  }
  
  res <- cbind(group_res, agg_res)
  colnames(res) <- c(by,agg.cols)
  lapply(by, function(col) {
    res[,col] <<- .set.type(res[,col], coltypes(x)[col])
  })
  res
  
}


#' Tukey Five-Number Summaries
#' 
#' Return Returns Tukey's five number summary (minimum, lower-hinge, median, upper-hinge, maximum) 
#' for each numeric column of a Distributed Data Frame.
#' @param x a Distributed Data Frame.
#' @return a data.frame in which each column is a vector containing the summary information.
#' @export

setMethod("fivenum",
          signature("DDF"),
          function(x) {
            # only numeric columns have those fivenum numbers
            col.names <- colnames(x)
            numeric.col.indices <- which(sapply(col.names, function(cn) {x@jddf$getColumn(cn)$isNumeric()})==TRUE)
            
            # call java API
            fns <- x@jddf$getFiveNumSummary()
            
            # extract values
            ret <- sapply(numeric.col.indices, function(idx) {fn <- fns[[idx]];
                                                c(fn$getMin(), fn$getFirstQuantile(), fn$getMedian(), 
                                                  fn$getThirdQuantile(), fn$getMax())})
            
            # set row names
            rownames(ret) <- c("Min.", "1st Qu.", "Median", "3rd Qu.",  "Max.")
            ret
          }
)

#' Calculate the variance and std of a column in DDF
#'
#' Return a vector with dimension 2, 1st dimension denotes the variance and 2ed dimension denotes the standard variance.
#' @param x a Distributed Data Frame.
#' @param y the column name or index of x
#' @return a vector with dimension 2.
#' @export
 
 setMethod("var",
          signature("DDF"),
          function(x, y) {
            cols <- colnames(x)
            colname <- y
            
            if(is.numeric(y)){
            # validate column index
              if (y < 0 || y > ncol(x) || !isInteger(y))
		 stop(paste0("Invalid column indices - ",y), call.=F)
	       colname <- as.character(cols[y])
	     }
						
	     # validate column name
	     if (!(colname %in% cols))
	       stop(paste0("Invalid column name - ",colname), call.=F)
							
	     ret <- sapply(x@jddf$getVectorVariance(colname), function(obj) {obj$toString()})
	     return (as.double(ret))
	  }
)

#' Drop NA values
#'
#' Return a DDF instance with no NAs.
#' @param object a Distributed Data Frame.
#' @param axis the axis by which to drop if NA value exits, ROW represents by Row as default, COLUMN is column.
#' @param inplace whether to treat the ddf inplace, default is FALSE.
#' @return a DDF with no NA values.
#' @export

setMethod("na.omit",
          signature("DDF"),
          function(object, axis=c("ROW","COLUMN"), inplace=FALSE) {
            axis <- match.arg(axis)
	     by <- J("io.ddf.etl.IHandleMissingData")$Axis$ROW			
	     if(axis=="COLUMN")
            	by <- J("io.ddf.etl.IHandleMissingData")$Axis$COLUMN

            if(!inplace)
               return (new("DDF", object@jddf$dropNA(by)))
            else{
               object@jddf$setMutable(inplace)
               object@jddf$dropNA(by)
               return (object)
            }
          }
)

#' Calculate Mean value of each DDF Column
#'
#' Return the mean value of each DDF column.
#' @param x a Distributed Data Frame.
#' @return a vector contains mean values of all columns
#' @export
 
setMethod("mean",
          signature("DDF"),
          function(x) {
          col.names <- colnames(x)
          ret <- sapply(col.names,function(colname) {
                    x@jddf$getVectorMean(colname)
          })
          return (ret)
        }
)

#' @export
setGeneric("sql",
           function(x, sql, ...) {
             standardGeneric("sql")
           }
)

setMethod("sql",
          signature("DDF"),
          function(x, sql) {
            sql <- str_trim(sql)
            jddf <- x@jddf
            java.ret <- jddf$sql(sql, "")
            parse.sql.result(java.ret)
          })


#' @export
setGeneric("sql2ddf",
           function(x, sql, ...) {
             standardGeneric("sql2ddf")
           }
)

setMethod("sql2ddf",
          signature("DDF"),
          function(x, sql) {
            sql <- str_trim(sql)
            jddf <- x@jddf
            new("DDF", jddf$sql2ddf(sql))
          })

#' Merge two DDFs
setMethod("merge",
          signature("DDF","DDF"),
          function(x, y, by = intersect(colnames(x), colnames(y)),
                   by.x = by, by.y = by, type=c("inner", "left", "right", "full", "left.semi")) {
            jddf <- x@jddf
            type <- match.arg(type)
            
            jjtype <- switch(type,
                             inner=J("io.ddf.etl.Types$JoinType")$INNER,
                             left=J("io.ddf.etl.Types$JoinType")$LEFT,
                             right=J("io.ddf.etl.Types$JoinType")$RIGHT,
                             full=J("io.ddf.etl.Types$JoinType")$FULL,
                             left.semi=J("io.ddf.etl.Types$JoinType")$LEFTSEMI)
            
            new("DDF", jddf$join(y@jddf, jjtype, to.jlist(by), to.jlist(by.x), to.jlist(by.y)))
          })

#----------------------- Helper methods ----------------------------------------------
to.jlist <- function(v) {
  jArrayList <- .jnew("java/util/ArrayList")
  lapply(v, function(x){
    if (is.character(x)) {
      jArrayList$add(.jnew("java/lang/String",x))
    }
  })
  jArrayList
}

parse.sql.result <- function(java.ret) {
  res <- java.ret$getRows()
  col.types <- sapply(java.ret$getSchema()$getColumns(), function(x) x$getType()$toString())
  col.names <- sapply(java.ret$getSchema()$getColumns(), function(x) x$getName())
  
  if(length(col.names)>1)
    res <- t(sapply(res, function(x){x$split("\t")}))
  else
    res <- as.matrix(sapply(res, function(x){x$split("\t")}))
  get.data.frame(col.names, col.types, res)
}

get.data.frame <- function(col.names, col.types, res) {
  df <- as.data.frame(res, stringsAsFactors=F)
  
  # set types
  sapply(1:ncol(df), function(idx) {col.type <- col.types[idx];
                                    df[,idx] <<- .set.type(df[,idx], col.type)})
  colnames(df) <- col.names
  df
}

.set.type <- function(v, type) {
  type <- switch(type,
         INT = "integer",
         LONG = "integer",
         DOUBLE = "double",
         FLOAT = "double",
         BOOLEAN = "logical",
         STRING = "character",
         character)
  fn <- paste("as", type, sep=".")
  do.call(fn, list(v))
  
}
