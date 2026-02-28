// merge_sort.c
void merge(int arr[], int l, int m, int r)
{
    int i, j, k;
    int n1 = m - l + 1;
    int n2 = r - m;
    int L[16], R[16];

    for (i = 0; i < n1; i++)
        L[i] = arr[l + i];
    for (j = 0; j < n2; j++)
        R[j] = arr[m + 1 + j];

    i = 0;
    j = 0;
    k = l;
    while (i < n1 && j < n2) {
        if (L[i] <= R[j]) {
            arr[k] = L[i];
            i++;
        } else {
            arr[k] = R[j];
            j++;
        }
        k++;
    }
    while (i < n1) {
        arr[k] = L[i];
        i++;
        k++;
    }
    while (j < n2) {
        arr[k] = R[j];
        j++;
        k++;
    }
}

void mergeSort(int arr[], int l, int r)
{
    if (l < r) {
        int m = l + (r - l) / 2;
        mergeSort(arr, l, m);
        mergeSort(arr, m + 1, r);
        merge(arr, l, m, r);
    }
}

// Unsorted array
int my_array[] = {5, 2, 4, 1, 3, 18, 14, -3, -4, 0};

int main()
{
    int arr_size = 10;

    // Sort the array
    mergeSort(my_array, 0, arr_size - 1);

    // VERIFICATION EXPORT:
    // Copy the sorted array to a hardcoded memory address: 0x00000800
    // This translates to dmem[512] (0x800 / 4 bytes per word = 512)
    volatile int *export_ptr = (volatile int *) 0x00000800;
    for (int i = 0; i < arr_size; i++) {
        export_ptr[i] = my_array[i];
    }

    return 0;
}