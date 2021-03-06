#' @rdname cluster
#' @title FlowSOM clustering & ConsensusClusterPlus metaclustering
#' 
#' @description 
#' \code{cluster} will first group cells into \code{xdim}x\code{ydim} 
#' clusters using \pkg{FlowSOM}, and subsequently perform metaclustering 
#' with \pkg{ConsensusClusterPlus} into 2 through \code{maxK} clusters. 
#' In the returned \code{daFrame}, those antigens used for clustering will be 
#' labelled as '\code{type}' markers, and the remainder of antigens as 
#' '\code{state}' markers.
#'
#' @param x a \code{\link[SingleCellExperiment]{SingleCellExperiment}}.
#' @param features a character vector. 
#'   Specifies which antigens to use for clustering. The default (NULL) 
#'   uses \code{type_markers(x)}. Must be provided if 
#'   \code{rowData(x)$marker_class} has not been specified.
#' @param xdim,ydim 
#'   numeric. Specify the grid size of the self-orginizing map. 
#'   The default 10x10 grid will yield 100 clusters. 
#' @param maxK 
#'   numeric. Specifies the maximum number of clusters to evaluate
#'   in the metaclustering. For \code{maxK = 20}, for example, 
#'   metaclustering will be performed for 2 through 20 clusters.
#' @param verbose logical. Should information on progress be reported?
#' @param seed numeric. Sets random seed in \code{ConsensusClusterPlus()}.
#' 
#' @return 
#' The function will add information to the following slots 
#' of the input \code{daFrame} (and return it):
#' \itemize{
#' \item{\code{rowData}\itemize{
#' \item{\code{cluster_id}:
#'   each cell's cluster ID as inferred by \code{FlowSOM}. 
#'   One of 1, ..., \code{xdim}x\code{ydim}.}
#' }}
#' \item{\code{colData}\itemize{
#' \item{\code{marker_class}: 
#'   \code{"type"} or \code{"state"}. 
#'   Specifies whether an antigen has been used for clustering 
#'   or not, respectively.}
#' }}
#' \item{\code{metadata}\itemize{
#' \item{\code{SOM_codes}:
#'   a table with dimensions K x (# cell type markers), 
#'   where K = \code{xdim} x \code{ydim}. Contains the SOM codes.}
#' \item{\code{cluster_codes}:
#'   a table with dimensions K x (\code{maxK} + 1). 
#'   Contains the cluster codes for all metaclustering.}
#' \item{\code{delta_area}: 
#'   a \code{\link{ggplot}} object. See above for details.}
#' }}
#' }
#' 
#' @details 
#' The delta area represents the amount of extra cluster stability gained when 
#' clustering into k groups as compared to k-1 groups. It can be expected that 
#' high stability of clusters can be reached when clustering into the number of 
#' groups that best fits the data. The "natural" number of clusters present in 
#' the data should thus corresponds to the value of k where there is no longer 
#' a considerable increase in stability (pleateau onset).
#' 
#' @author Helena Lucia Crowell \email{helena.crowell@@uzh.ch}
#' 
#' @references 
#' Nowicka M, Krieg C, Weber LM et al. 
#' CyTOF workflow: Differential discovery in 
#' high-throughput high-dimensional cytometry datasets.
#' \emph{F1000Research} 2017, 6:748 (doi: 10.12688/f1000research.11622.1)
#' 
#' @examples
#' # construct SCE
#' data(PBMC_fs, PBMC_panel, PBMC_md)
#' sce <- prepData(PBMC_fs, PBMC_panel, PBMC_md)
#' 
#' # run clustering
#' (sce <- cluster(sce))
#' 
#' @import ConsensusClusterPlus ggplot2
#' @importFrom dplyr %>% mutate_all
#' @importFrom flowCore flowFrame
#' @importFrom FlowSOM BuildSOM ReadInput
#' @importFrom graphics hist
#' @importFrom magrittr set_colnames
#' @importFrom matrixStats colQuantiles
#' @importFrom purrr map
#' @importFrom reshape2 melt
#' @importFrom SummarizedExperiment assay rowData rowData<-
#' @importFrom S4Vectors DataFrame
#' @export

cluster <- function(x, features = NULL,
    xdim=10, ydim=10, maxK=20, verbose=TRUE, seed=1) {
    
    # validity checks
    stopifnot(is(x, "SingleCellExperiment"))
    stopifnot(is.logical(verbose), length(verbose) == 1,
        vapply(list(xdim, ydim, maxK, seed), function(arg) 
            is.numeric(arg) && length(arg) == 1, logical(1)))
    
    if (is.null(features)) {
        stopifnot("marker_class" %in% colnames(rowData(x)))
        features <- type_markers(x)
        if (length(features) < 2)
            stop("<=2 antigens have been assigned",
                " to class ", dQuote("type"), ".")
    } else {
        # replace problematic characters
        features <- gsub("-", "_", features)
        features <- gsub(":", ".", features)
        stopifnot(features %in% rownames(x))
        # assign marker classes
        rowData(x)$marker_class <- factor(c("state", "type")[
            as.numeric(rownames(x) %in% features)+1],
            levels=c("type", "state", "none"))
    }
    
    # flowSOM clustering
    if (verbose)
        message("o running FlowSOM clustering...")
    fsom <- ReadInput(flowFrame(t(assay(x, "exprs"))))
    som <- BuildSOM(fsom, colsToUse=features, 
        silent=TRUE, xdim=xdim, ydim=ydim)
    
    # metaclustering
    if (verbose)
        message("o running ConsensusClusterPlus metaclustering...")
    pdf(NULL)
    mc <- suppressMessages(ConsensusClusterPlus(t(som$map$codes), 
        maxK=maxK, reps=100, distance="euclidean", seed=seed, plot=NULL))
    dev.off()
    
    # get cluster codes
    k <- xdim * ydim
    mcs <- seq_len(maxK)[-1]
    
    codes <- data.frame(seq_len(k), map(mc[-1], "consensusClass"))
    codes <- mutate_all(codes, function(u) factor(u, levels = sort(unique(u))))
    colnames(codes) <- c(sprintf("som%s", k), sprintf("meta%s", mcs))
    
    x$cluster_id <- factor(som$map$mapping[, 1])
    metadata(x)$cluster_codes <- codes
    metadata(x)$SOM_codes <- som$map$codes
    metadata(x)$delta_area <- .plot_delta_area(mc)
    return(x)
}
