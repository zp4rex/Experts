//+------------------------------------------------------------------+
//|                                                     ZP_Trade.mq4 |
//|                        Copyright 2017, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property library
#property copyright "Copyright 2017, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

bool isNewBar(int lastBarsNumber)
{    
    bool retVal = FALSE;
    
    if(lastBarsNumber < Bars(_Symbol,_Period))
    {
        retVal = TRUE;
    }
    
    return retVal;
}

bool orderOpened(int orderMagicNum)
{
    bool retVal = FALSE;

    for(int i = 0; i < OrdersTotal(); i++)
    {
        if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES) == FALSE)
        {
            break;
        }
        if((OrderSymbol() == Symbol()) && (OrderMagicNumber() == orderMagicNum))
        {
            if((OrderType() == OP_BUY) || (OrderType() == OP_SELL))
            {
                retVal = TRUE;                                
            }
        }
    }  

    return retVal;
}