float baseline(int n,double a[n][n])
{
    int i,j;
    double s=0.0;
    for(j=0;j<n;j++)
        for(i=0;i<n;i++)
            s += a[i][j];
    return s;
}

