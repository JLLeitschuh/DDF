package io.ddf2;

import io.ddf2.datasource.IDataSource;
import io.ddf2.datasource.schema.ISchema;
import io.ddf2.handlers.*;


/**
 * a DDF have an unique Name, schema & datasource.
 * a DDF is a table-like abstraction which provide custom function via its handler.
 * @see IStatisticHandler
 * @see IViewHandler
 * @see IMLHandler
 */
public interface IDDF {


    public IDataSource getDataSource();

    public String getDDFName();

    public ISchema getSchema();

    public int getNumColumn();

    public ISqlResult sql(String sql);
    public IDDF sql2ddf(String sql) throws DDFException;

    public long getNumRows();

    public IStatisticHandler getStatisticHandler();

    public IViewHandler getViewHandler();

    public IMLHandler getMLHandler();

    public IMLMetricHandler getMLMetricHandler();

    public IAggregationHandler getAggregationHandler();

    public IBinningHandler getBinningHandler();

    public ITransformHandler getTransformHandler();

}
 